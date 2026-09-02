-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_anular_pago
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.666Z
DROP FUNCTION IF EXISTS fin_anular_pago(p_id_pago integer, p_tipo character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_anular_pago(p_id_pago integer, p_tipo character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo INT;
    v_pago    fin_pago%ROWTYPE;
    v_cuenta  fin_cuenta%ROWTYPE;
    v_err_caja TEXT;
    v_id_sucursal INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_pago FROM fin_pago WHERE id = p_id_pago AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', 'El pago no existe o ya fue anulado');
    END IF;

    v_id_sucursal := COALESCE(v_pago.id_sucursal, fin_sucursal_de_cuenta(v_pago.id_cuenta));
    v_err_caja := fin_caja_assert_abierta(v_pago.fecha_pago, v_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', v_err_caja);
    END IF;

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = v_pago.id_cuenta;

    IF p_tipo IS NOT NULL THEN
        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera'
          AND glo.nombre = UPPER(p_tipo)
        LIMIT 1;

        IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
            RETURN json_build_object('eliminado', false, 'id', p_id_pago, 'error', 'El pago no corresponde al tipo indicado');
        END IF;
    END IF;

    UPDATE fin_pago
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id_pago;

    UPDATE fin_cuenta
       SET monto_abonado = fin_redondear_monto(GREATEST(COALESCE(monto_abonado, 0) - v_pago.monto, 0)),
           monto_saldo   = fin_redondear_monto(
               GREATEST(monto_pendiente - GREATEST(COALESCE(monto_abonado, 0) - v_pago.monto, 0), 0)
           ),
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = v_pago.id_cuenta;

    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        PERFORM fin_refrescar_cabecera_plan(v_cuenta.id_cuenta_padre);
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id_pago);
END;
$function$
