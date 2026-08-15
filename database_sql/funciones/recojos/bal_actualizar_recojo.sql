DROP FUNCTION IF EXISTS bal_actualizar_recojo(INTEGER, INTEGER, DATE, TIME, INTEGER, VARCHAR, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS bal_actualizar_recojo(INTEGER, INTEGER, INTEGER, DATE, TIME, INTEGER, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION bal_actualizar_recojo(
    p_id INTEGER,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_alquiler INTEGER DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_estimada TIME DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_estado_nombre VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_estado_actual VARCHAR;
    v_estado_nuevo VARCHAR;
    v_id_estado INTEGER;
    v_id_estado_prestado INTEGER;
    v_id_estado_alquilado INTEGER;
    v_det RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, er.nombre
    INTO v_id_cliente, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se pueden editar recojos en estado PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo
        WHERE id = p_id_prestamo AND estado = 1 AND id_cliente = v_id_cliente
    ) THEN
        RETURN json_build_object(
            'error', 'El préstamo no existe, está inactivo o no pertenece al cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_alquiler
        WHERE id = p_id_alquiler AND estado = 1 AND id_cliente = v_id_cliente
    ) THEN
        RETURN json_build_object(
            'error', 'El alquiler no existe, está inactivo o no pertenece al cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id = p_id_usuario_responsable AND estado = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El usuario responsable no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    v_estado_nuevo := NULLIF(UPPER(TRIM(p_estado_nombre)), '');
    IF v_estado_nuevo IS NOT NULL THEN
        IF v_estado_nuevo NOT IN ('PROGRAMADO', 'EN_RUTA', 'CANCELADO') THEN
            RETURN json_build_object(
                'error', 'Estado no permitido en actualización: ' || v_estado_nuevo,
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_nuevo AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el estado ' || v_estado_nuevo || ' en EstadoRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    IF v_estado_nuevo = 'CANCELADO' AND v_estado_actual <> 'CANCELADO' THEN
        SELECT lo.id INTO v_id_estado_prestado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_alquilado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_prestado IS NOT NULL THEN
            FOR v_det IN
                SELECT pd.id_balon
                FROM bal_recojo_detalle rd
                INNER JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
                INNER JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                WHERE rd.id_recojo = p_id
                  AND rd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND eb.nombre = 'POR_RECOGER'
            LOOP
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_prestado,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_det.id_balon;
            END LOOP;
        END IF;

        IF v_id_estado_alquilado IS NOT NULL THEN
            FOR v_det IN
                SELECT ad.id_balon
                FROM bal_recojo_detalle rd
                INNER JOIN bal_alquiler_detalle ad ON ad.id = rd.id_alquiler_detalle AND ad.estado = 1
                INNER JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
                INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                WHERE rd.id_recojo = p_id
                  AND rd.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND eb.nombre = 'POR_RECOGER'
            LOOP
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_alquilado,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_det.id_balon;
            END LOOP;
        END IF;
    END IF;

    UPDATE bal_recojo
    SET
        id_prestamo = COALESCE(p_id_prestamo, id_prestamo),
        id_alquiler = COALESCE(p_id_alquiler, id_alquiler),
        fecha_programada = COALESCE(p_fecha_programada, fecha_programada),
        hora_estimada = COALESCE(p_hora_estimada, hora_estimada),
        id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable),
        id_estado = COALESCE(v_id_estado, id_estado),
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$;
