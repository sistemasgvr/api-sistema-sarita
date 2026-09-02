-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_vincular_recarga_cliente_comprobante
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.610Z
DROP FUNCTION IF EXISTS bal_vincular_recarga_cliente_comprobante(p_id_comprobante integer, p_id_cliente integer, p_id_balon integer, p_id_producto integer, p_capacidad numeric, p_id_almacen integer, p_observacion character varying, p_id_balon_origen integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_vincular_recarga_cliente_comprobante(p_id_comprobante integer, p_id_cliente integer, p_id_balon integer, p_id_producto integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_almacen integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_balon_origen integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_tipo_recarga INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_recarga INTEGER;
    v_serie_comprobante VARCHAR;
    v_numero_comprobante VARCHAR;
    v_capacidad NUMERIC;
    v_capacidad_destino NUMERIC;
    v_recarga JSON;
    v_asignacion JSON;
    v_origenes JSON;
    v_id_balon_origen_principal INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := CURRENT_DATE;

    IF p_id_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'El producto (gas) es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_balon_origen IS NOT NULL AND p_id_balon_origen = p_id_balon THEN
        RETURN json_build_object(
            'error',
            'El balón origen no puede ser el mismo que el destino',
            'registro',
            NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1 AND es_gas = TRUE
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no es un gas activo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_movimiento_recarga
        WHERE id_comprobante = p_id_comprobante
          AND id_balon = p_id_balon
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe una recarga vinculada a este comprobante y balón',
            'registro',
            NULL
        );
    END IF;

    -- Capacidad del tipo convertida a la unidad del producto-gas (canónica de pro_stock).
    SELECT
        COALESCE(bal_capacidad_balon_en_unidad_gas(b.id), p_capacidad, 0)
    INTO v_capacidad_destino
    FROM bal_balon b
    WHERE b.id = p_id_balon;

    v_capacidad := COALESCE(NULLIF(p_capacidad, 0), v_capacidad_destino, 0);

    IF v_capacidad <= 0 THEN
        RETURN json_build_object(
            'error',
            'No se pudo determinar la capacidad a recargar',
            'registro',
            NULL
        );
    END IF;

    v_asignacion := bal_asignar_origenes_recarga(
        p_id_producto,
        v_capacidad,
        p_id_almacen,
        p_id_balon_origen
    );

    IF v_asignacion->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_asignacion->>'error', 'registro', NULL);
    END IF;

    v_origenes := v_asignacion->'origenes';
    v_id_balon_origen_principal := (v_asignacion->>'id_balon_origen_principal')::INTEGER;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'RECARGA_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_movimiento IS NULL THEN
        SELECT lo.id INTO v_id_tipo_movimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'RECARGA' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT serie, numero INTO v_serie_comprobante, v_numero_comprobante
    FROM ven_comprobante
    WHERE id = p_id_comprobante;

    -- El stock de gas ya se validó en bal_asignar_origenes_recarga (pro_stock) y se
    -- descuenta más abajo vía inv_registrar_movimiento; ya no hay capacidad por
    -- cilindro que "consumir" aparte.

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen,
        id_balon,
        id_balon_origen,
        id_cliente,
        id_tipo_recarga,
        id_producto,
        capacidad,
        serie_factura,
        numero_factura,
        id_comprobante,
        fecha_llegada_almacen,
        observacion,
        id_almacen,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_fecha,
        p_id_balon,
        v_id_balon_origen_principal,
        p_id_cliente,
        v_id_tipo_recarga,
        p_id_producto,
        v_capacidad,
        v_serie_comprobante,
        v_numero_comprobante,
        p_id_comprobante,
        v_fecha,
        CASE
            WHEN COALESCE(v_asignacion->>'etiqueta', '') <> '' THEN
                TRIM(BOTH ' ' FROM CONCAT_WS(
                    ' | ',
                    NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
                    'Orígenes: ' || (v_asignacion->>'etiqueta')
                ))
            ELSE p_observacion
        END,
        p_id_almacen,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_recarga;

    INSERT INTO bal_movimiento_recarga_origen (
        id_movimiento_recarga,
        id_balon,
        cantidad,
        orden,
        id_usuario_creacion
    )
    SELECT
        v_id_recarga,
        (o->>'id_balon')::INTEGER,
        (o->>'cantidad')::NUMERIC,
        COALESCE((o->>'orden')::INTEGER, 1),
        p_id_usuario_auditoria
    FROM json_array_elements(v_origenes) o;

    IF v_id_tipo_movimiento IS NOT NULL THEN
        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'RECARGA_CLIENTE',
            p_fecha                     => NOW(),
            p_id_producto               => p_id_producto,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => v_capacidad,
            p_id_almacen_origen         => p_id_almacen,
            p_id_almacen_destino        => NULL,
            p_id_cliente                => p_id_cliente,
            p_codigo_tipo_documento_origen => 'RECARGA',
            p_id_documento_origen       => v_id_recarga,
            p_glosa                     => COALESCE(p_observacion, 'Recarga cliente (POS)'),
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;
    END IF;

    -- inv_registrar_movimiento ya actualizó id_estado_balon, id_cliente_ubicacion, id_almacen.
    -- Solo fijamos id_producto_gas y limpiamos presion/contenido.
    UPDATE bal_balon
    SET
        id_producto_gas = p_id_producto,
        presion_actual = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    v_recarga := bal_obtener_movimiento_recarga(v_id_recarga);

    RETURN json_build_object('registro', v_recarga->'registro');
END;
$function$
