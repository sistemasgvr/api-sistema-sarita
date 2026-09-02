-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.531Z
DROP FUNCTION IF EXISTS bal_crear_mantenimiento(p_id_balon integer, p_fecha_ingreso date, p_id_tipo_mantenimiento integer, p_fecha_salida date, p_descripcion character varying, p_costo numeric, p_es_externo boolean, p_id_proveedor integer, p_id_estado integer, p_id_comprobante_venta integer, p_id_comprobante_compra integer, p_observacion character varying, p_id_usuario_auditoria integer, p_vigencia_ph_anios integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_numero_certificado_ph character varying);

CREATE OR REPLACE FUNCTION bal_crear_mantenimiento(p_id_balon integer, p_fecha_ingreso date, p_id_tipo_mantenimiento integer DEFAULT NULL::integer, p_fecha_salida date DEFAULT NULL::date, p_descripcion character varying DEFAULT NULL::character varying, p_costo numeric DEFAULT 0, p_es_externo boolean DEFAULT false, p_id_proveedor integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_vigencia_ph_anios integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT NULL::boolean, p_numero_certificado_ph character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado_balon_mantenimiento INTEGER;
    v_id_estado_mantenimiento INTEGER;
    v_id_estado_finalizado INTEGER;
    v_id_almacen INTEGER;
    v_id_cliente_ubicacion INTEGER;
    v_id_cliente_propietario INTEGER;
    v_id_cliente_mov INTEGER;
    v_nombre_propietario VARCHAR;
    v_es_servicio_cliente BOOLEAN;
    v_mov_result JSON;
    v_obs_movimiento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_ingreso IS NULL THEN
        RETURN json_build_object('error', 'La fecha de ingreso es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT
        b.id_almacen,
        b.id_cliente_ubicacion,
        b.id_cliente_propietario,
        UPPER(COALESCE(prop.nombre, ''))
    INTO
        v_id_almacen,
        v_id_cliente_ubicacion,
        v_id_cliente_propietario,
        v_nombre_propietario
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    WHERE b.id = p_id_balon AND b.estado = 1;

    -- Servicio entrante: cilindro del cliente o envase que viene con ubicación de cliente
    -- (ej. prestado / propio traído a taller). Inventario: sin cliente, stock de empresa.
    v_es_servicio_cliente := (
        v_nombre_propietario = 'CLIENTE'
        OR v_id_cliente_ubicacion IS NOT NULL
    );

    v_id_cliente_mov := COALESCE(
        v_id_cliente_ubicacion,
        v_id_cliente_propietario
    );

    IF p_id_comprobante_venta IS NOT NULL AND v_id_cliente_mov IS NULL THEN
        SELECT id_cliente INTO v_id_cliente_mov
        FROM ven_comprobante
        WHERE id = p_id_comprobante_venta AND estado = 1;
    END IF;

    SELECT lo.id INTO v_id_estado_balon_mantenimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_MANTENIMIENTO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_balon_mantenimiento IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado EN_MANTENIMIENTO del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    IF p_id_estado IS NULL THEN
        SELECT lo.id INTO v_id_estado_mantenimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;
    ELSIF v_id_estado_finalizado IS NOT NULL AND p_id_estado = v_id_estado_finalizado THEN
        RETURN json_build_object(
            'error', 'No se puede crear un mantenimiento finalizado. Use la acción Finalizar.',
            'registro', NULL
        );
    ELSE
        v_id_estado_mantenimiento := p_id_estado;
    END IF;

    IF v_es_servicio_cliente THEN
        v_obs_movimiento := COALESCE(p_observacion, 'Recepción de cilindro para servicio de mantenimiento');
    ELSE
        v_obs_movimiento := COALESCE(p_observacion, 'Salida a mantenimiento');
    END IF;

    INSERT INTO bal_mantenimiento (
        id_balon, id_tipo_mantenimiento, fecha_ingreso, fecha_salida,
        descripcion, costo, es_externo, id_proveedor, id_estado,
        id_comprobante_venta, id_comprobante_compra, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_tipo_mantenimiento, p_fecha_ingreso, p_fecha_salida,
        p_descripcion, COALESCE(p_costo, 0), COALESCE(p_es_externo, FALSE), p_id_proveedor,
        v_id_estado_mantenimiento,
        p_id_comprobante_venta, p_id_comprobante_compra, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF v_es_servicio_cliente THEN
        v_mov_result := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_MANTENIMIENTO',
            p_fecha                     => p_fecha_ingreso,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_destino        => v_id_almacen,
            p_id_cliente                => v_id_cliente_mov,
            p_codigo_tipo_documento_origen => 'MANTENIMIENTO',
            p_id_documento_origen       => v_id,
            p_glosa                     => v_obs_movimiento,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
    ELSE
        v_mov_result := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'SALIDA_MANTENIMIENTO',
            p_fecha                     => p_fecha_ingreso,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_origen         => v_id_almacen,
            p_id_cliente                => v_id_cliente_mov,
            p_codigo_tipo_documento_origen => 'MANTENIMIENTO',
            p_id_documento_origen       => v_id,
            p_glosa                     => v_obs_movimiento,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
    END IF;

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- Custodia en taller: EN_MANTENIMIENTO. Contenido: vacío (purga / PH / reparación).
    -- No se borra id_cliente_ubicacion (sirve para devolver al cliente al finalizar).
    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado_balon_mantenimiento,
        id_cliente_ubicacion = CASE
            WHEN v_es_servicio_cliente THEN COALESCE(id_cliente_ubicacion, v_id_cliente_mov)
            ELSE id_cliente_ubicacion
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_sync_ph_desde_mantenimiento(
        v_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(v_id);
END;
$function$
