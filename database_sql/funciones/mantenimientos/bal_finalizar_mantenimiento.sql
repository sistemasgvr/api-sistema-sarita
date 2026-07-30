CREATE OR REPLACE FUNCTION bal_finalizar_mantenimiento(
    p_id INTEGER,
    p_fecha_salida DATE DEFAULT CURRENT_DATE,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_vigencia_ph_anios INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT NULL,
    p_numero_certificado_ph VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_id_cliente_ubicacion INTEGER;
    v_id_cliente_propietario INTEGER;
    v_id_cliente_comprobante INTEGER;
    v_id_cliente_destino INTEGER;
    v_nombre_propietario VARCHAR;
    v_nombre_estado VARCHAR;
    v_es_servicio_cliente BOOLEAN;
    v_id_almacen_destino INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_estado_finalizado INTEGER;
    v_id_estado_destino INTEGER;
    v_mov_result JSON;
    v_obs_movimiento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_balon,
        em.nombre,
        b.id_almacen,
        b.id_cliente_ubicacion,
        b.id_cliente_propietario,
        UPPER(COALESCE(prop.nombre, '')),
        cv.id_cliente
    INTO
        v_id_balon,
        v_nombre_estado,
        v_id_almacen,
        v_id_cliente_ubicacion,
        v_id_cliente_propietario,
        v_nombre_propietario,
        v_id_cliente_comprobante
    FROM bal_mantenimiento m
    INNER JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    LEFT JOIN ven_comprobante cv ON cv.id = m.id_comprobante_venta AND cv.estado = 1
    WHERE m.id = p_id
      AND m.estado = 1;

    IF v_id_balon IS NULL THEN
        RETURN json_build_object(
            'error', 'El mantenimiento no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF UPPER(COALESCE(v_nombre_estado, '')) = 'FINALIZADO' THEN
        RETURN json_build_object(
            'error', 'El mantenimiento ya está finalizado',
            'registro', NULL
        );
    END IF;

    v_es_servicio_cliente := (
        v_nombre_propietario = 'CLIENTE'
        OR v_id_cliente_ubicacion IS NOT NULL
    );

    -- Inventario empresa: sin dueño cliente ni ubicación en cliente → reingreso a almacén
    -- (el comprobante de venta solo indica cobro del servicio, no cambia la custodia del envase)

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_finalizado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado FINALIZADO de mantenimiento',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'MANTENIMIENTO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_mantenimiento
    SET
        fecha_salida = COALESCE(p_fecha_salida, CURRENT_DATE),
        id_estado = v_id_estado_finalizado,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    IF v_es_servicio_cliente THEN
        v_id_cliente_destino := COALESCE(
            v_id_cliente_ubicacion,
            v_id_cliente_propietario,
            v_id_cliente_comprobante
        );

        SELECT lo.id INTO v_id_tipo_movimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_ENTREGA_CLIENTE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_movimiento IS NULL THEN
            SELECT lo.id INTO v_id_tipo_movimiento
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_MANTENIMIENTO' AND lo.estado = 1
            LIMIT 1;
        END IF;

        IF v_nombre_propietario = 'CLIENTE' THEN
            SELECT lo.id INTO v_id_estado_destino
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_PODER_CLIENTE' AND lo.estado = 1
            LIMIT 1;
        ELSE
            -- Envase de empresa que estaba prestado / con el cliente
            SELECT lo.id INTO v_id_estado_destino
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;
        END IF;

        v_obs_movimiento := COALESCE(
            NULLIF(TRIM(p_observacion), ''),
            'Entrega al cliente tras servicio de mantenimiento'
        );

        IF v_id_tipo_movimiento IS NOT NULL THEN
            v_mov_result := bal_crear_movimiento(
                v_id_balon,
                v_id_tipo_movimiento,
                p_id,
                v_id_tipo_documento_ref,
                v_id_cliente_destino,
                v_id_almacen,
                NULL,
                COALESCE(p_fecha_salida, CURRENT_DATE)::TIMESTAMP,
                v_obs_movimiento,
                p_id_usuario_auditoria
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_almacen = NULL,
            id_cliente_ubicacion = v_id_cliente_destino,
            id_estado_balon = COALESCE(v_id_estado_destino, id_estado_balon),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;
    ELSE
        -- Inventario empresa: reingreso a almacén
        v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

        IF v_id_almacen_destino IS NULL THEN
            RETURN json_build_object(
                'error', 'Debe indicar el almacén de destino del reingreso',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El almacén de destino no existe o está inactivo',
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_tipo_movimiento
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_MANTENIMIENTO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_movimiento IS NULL THEN
            SELECT lo.id INTO v_id_tipo_movimiento
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
            LIMIT 1;
        END IF;

        SELECT lo.id INTO v_id_estado_destino
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        v_obs_movimiento := COALESCE(
            NULLIF(TRIM(p_observacion), ''),
            'Entrada por finalización de mantenimiento'
        );

        IF v_id_tipo_movimiento IS NOT NULL THEN
            v_mov_result := bal_crear_movimiento(
                v_id_balon,
                v_id_tipo_movimiento,
                p_id,
                v_id_tipo_documento_ref,
                NULL,
                NULL,
                v_id_almacen_destino,
                COALESCE(p_fecha_salida, CURRENT_DATE)::TIMESTAMP,
                v_obs_movimiento,
                p_id_usuario_auditoria
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen_destino,
            id_estado_balon = COALESCE(v_id_estado_destino, id_estado_balon),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;
    END IF;

    PERFORM bal_sync_ph_desde_mantenimiento(
        p_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(p_id);
END;
$function$;
