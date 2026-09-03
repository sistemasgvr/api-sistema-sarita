-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_prestamo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
DROP FUNCTION IF EXISTS bal_actualizar_prestamo(p_id integer, p_numero_prestamo character varying, p_id_tipo_prestamo integer, p_id_cliente integer, p_id_proveedor integer, p_id_almacen integer, p_fecha_salida date, p_fecha_retorno_pactada date, p_fecha_retorno_real date, p_titulo character varying, p_observacion character varying, p_id_estado integer, p_id_comprobante_venta integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_prestamo(p_id integer, p_numero_prestamo character varying DEFAULT NULL::character varying, p_id_tipo_prestamo integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_salida date DEFAULT NULL::date, p_fecha_retorno_pactada date DEFAULT NULL::date, p_fecha_retorno_real date DEFAULT NULL::date, p_titulo character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero VARCHAR;
    v_id_cliente_actual INTEGER;
    v_pendientes INTEGER;
    v_nombre_estado_nuevo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero := NULLIF(TRIM(p_numero_prestamo), '');

    IF v_numero IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_prestamo WHERE numero_prestamo = v_numero AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro préstamo con el número ' || v_numero, 'registro', NULL);
    END IF;

    SELECT id_cliente INTO v_id_cliente_actual
    FROM bal_prestamo
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = p_id AND estado = 1 AND fecha_devolucion IS NULL;

    IF p_id_estado IS NOT NULL THEN
        SELECT lo.nombre INTO v_nombre_estado_nuevo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_estado AND lo.estado = 1;
    END IF;

    IF COALESCE(v_pendientes, 0) > 0
       AND (
           UPPER(COALESCE(v_nombre_estado_nuevo, '')) = 'CERRADO'
           OR p_fecha_retorno_real IS NOT NULL
       )
    THEN
        RETURN json_build_object(
            'error',
            'No se puede cerrar el préstamo: aún hay cilindros pendientes de devolución',
            'registro', NULL
        );
    END IF;

    UPDATE bal_prestamo
    SET
        numero_prestamo = COALESCE(v_numero, numero_prestamo),
        id_tipo_prestamo = COALESCE(p_id_tipo_prestamo, id_tipo_prestamo),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        fecha_retorno_pactada = COALESCE(p_fecha_retorno_pactada, fecha_retorno_pactada),
        fecha_retorno_real = COALESCE(p_fecha_retorno_real, fecha_retorno_real),
        titulo = COALESCE(p_titulo, titulo),
        observacion = COALESCE(p_observacion, observacion),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- Si cambia el cliente, la ubicación de los cilindros aún prestados sigue al préstamo.
    IF p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM v_id_cliente_actual THEN
        UPDATE bal_balon b
        SET
            id_cliente_ubicacion = p_id_cliente,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM bal_prestamo_detalle pd
        WHERE pd.id_prestamo = p_id
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon = b.id
          AND b.estado = 1;
    END IF;

    RETURN bal_obtener_prestamo(p_id);
END;
$function$;
