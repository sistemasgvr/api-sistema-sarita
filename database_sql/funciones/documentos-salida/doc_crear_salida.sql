-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_crear_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_crear_salida(p_codigo_tipo_orden character varying, p_id_sucursal integer, p_id_almacen integer, p_id_venta integer, p_id_cliente integer, p_id_destinatario integer, p_id_proveedor integer, p_id_doc_salida_origen integer, p_fecha date, p_fecha_traslado date, p_observaciones character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_crear_salida(p_codigo_tipo_orden character varying, p_id_sucursal integer, p_id_almacen integer, p_id_venta integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_id_doc_salida_origen integer DEFAULT NULL::integer, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_orden INTEGER;
    v_id_borrador INTEGER;
    v_numero VARCHAR;
    v_id INTEGER;
    v_fecha DATE;
    v_id_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);

    SELECT lo.id INTO v_id_tipo_orden
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrdenSalida' AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_orden, ''))) AND lo.estado = 1;

    IF v_id_tipo_orden IS NULL THEN
        RETURN json_build_object('error', format('Tipo de orden %s no configurado', p_codigo_tipo_orden), 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_borrador
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'BORRADOR' AND lo.estado = 1;

    IF p_id_sucursal IS NULL THEN
        RETURN json_build_object('error', 'La sucursal es obligatoria', 'registro', NULL);
    END IF;

    v_id_almacen := p_id_almacen;
    IF v_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen AND id_sucursal = p_id_sucursal AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén no existe o no pertenece a la sucursal indicada', 'registro', NULL);
    END IF;

    IF p_id_venta IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM ven_comprobante WHERE id = p_id_venta AND estado = 1) THEN
            RETURN json_build_object('error', 'La venta indicada no existe o está anulada', 'registro', NULL);
        END IF;

        -- Una venta no debería tener dos órdenes vivas: duplicaría el documento de traslado.
        IF EXISTS (
            SELECT 1 FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = p_id_venta AND d.estado = 1 AND ec.nombre <> 'ANULADA'
        ) THEN
            RETURN json_build_object('error', 'Esta venta ya tiene una orden de salida vigente', 'registro', NULL);
        END IF;
    END IF;

    v_numero := doc_obtener_siguiente_numero(p_id_sucursal, v_fecha);

    INSERT INTO doc_salida (
        numero, id_tipo_orden, id_estado_ciclo, emitido_sunat,
        id_venta, id_doc_salida_origen,
        id_sucursal, id_almacen, id_cliente, id_destinatario, id_proveedor,
        fecha, fecha_traslado, observaciones,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        v_numero, v_id_tipo_orden, v_id_borrador, FALSE,
        p_id_venta, p_id_doc_salida_origen,
        p_id_sucursal, v_id_almacen,
        COALESCE(p_id_cliente, (SELECT id_cliente FROM ven_comprobante WHERE id = p_id_venta)),
        p_id_destinatario, p_id_proveedor,
        v_fecha, p_fecha_traslado, p_observaciones,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN doc_obtener_salida(v_id);
END;
$function$;
