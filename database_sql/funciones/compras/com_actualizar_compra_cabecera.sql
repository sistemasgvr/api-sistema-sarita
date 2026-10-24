-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_actualizar_compra_cabecera
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   p_id_medio_pago / p_id_cuenta_bancaria / p_numero_operacion. Con medio se
--   reemplazan los tres (la cuenta y el Nº de operación dependen del medio);
--   sin medio se conservan. Si el cambio altera el pago que la compra aporta a
--   la caja (medio, importe o paso contado ↔ crédito), la caja de la compra
--   debe estar abierta: com_assert_caja_compra.
DROP FUNCTION IF EXISTS com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying, p_id_condicion_pago integer, p_id_categoria_gasto integer, p_declarar_sunat boolean, p_id_usuario_auditoria integer, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying, p_id_condicion_pago integer, p_id_categoria_gasto integer, p_declarar_sunat boolean, p_id_usuario_auditoria integer, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb, p_id_medio_pago integer, p_id_cuenta_bancaria integer, p_numero_operacion character varying);

CREATE OR REPLACE FUNCTION com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying DEFAULT NULL::character varying, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT NULL::boolean, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb, p_id_medio_pago integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer, p_numero_operacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pago_antes JSONB;
    v_tenia_cxp BOOLEAN;
    v_err TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL THEN
        v_err := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'registro', NULL);
        END IF;
    END IF;

    v_pago_antes := com_pago_caja_compra(p_id_comprobante);
    v_tenia_cxp := EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    );

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_medio_pago       = COALESCE(p_id_medio_pago, id_medio_pago),
        id_cuenta_bancaria  = CASE WHEN p_id_medio_pago IS NOT NULL THEN p_id_cuenta_bancaria ELSE id_cuenta_bancaria END,
        numero_operacion    = CASE WHEN p_id_medio_pago IS NOT NULL THEN NULLIF(TRIM(p_numero_operacion), '') ELSE numero_operacion END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = p_id_comprobante;
    ELSIF v_tenia_cxp AND EXISTS (
        -- Pasó de crédito a contado: ahora se paga en el momento. Una compra al
        -- contado de antes de 20261023 sin medio se puede seguir editando.
        SELECT 1 FROM com_comprobante_compra
        WHERE id = p_id_comprobante AND id_medio_pago IS NULL AND COALESCE(total_importe, 0) > 0
    ) THEN
        RAISE EXCEPTION 'Indica el medio de pago: al pasar la compra a contado se paga en el momento.';
    END IF;

    v_err := com_assert_caja_compra(v_pago_antes, com_pago_caja_compra(p_id_comprobante));
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;
