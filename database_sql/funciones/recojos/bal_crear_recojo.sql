CREATE OR REPLACE FUNCTION bal_crear_recojo(
    p_id_cliente INTEGER,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_estimada TIME DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_id_estado_por_recoger INTEGER;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_balon INTEGER;
    v_id_cliente_pd INTEGER;
    v_fecha_dev DATE;
    v_obs VARCHAR(500);
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'El cliente no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_fecha_programada IS NULL THEN
        RETURN json_build_object('error', 'La fecha programada es obligatoria', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
        RETURN json_build_object(
            'error', 'Debe indicar al menos un detalle de préstamo a recoger',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_prestamo
            WHERE id = p_id_prestamo AND estado = 1 AND id_cliente = p_id_cliente
        ) THEN
            RETURN json_build_object(
                'error', 'El préstamo no existe, está inactivo o no pertenece al cliente',
                'registro', NULL
            );
        END IF;
    END IF;

    IF p_id_usuario_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id = p_id_usuario_responsable AND estado = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El usuario responsable no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = 'PROGRAMADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado PROGRAMADO. Revise el catálogo EstadoRecojo.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_por_recoger
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'POR_RECOGER' AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_recojo (
        id_cliente, id_prestamo, fecha_programada, hora_estimada,
        id_usuario_responsable, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_id_prestamo, p_fecha_programada, p_hora_estimada,
        p_id_usuario_responsable, v_id_estado, NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles::JSONB)
    LOOP
        v_id_pd := COALESCE(
            NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
        );
        v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');

        IF v_id_pd IS NULL THEN
            RETURN json_build_object(
                'error', 'Detalle sin id_prestamo_detalle',
                'registro', NULL
            );
        END IF;

        SELECT pd.id_balon, p.id_cliente, pd.fecha_devolucion
        INTO v_id_balon, v_id_cliente_pd, v_fecha_dev
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        WHERE pd.id = v_id_pd AND pd.estado = 1;

        IF v_id_cliente_pd IS NULL THEN
            RETURN json_build_object(
                'error', 'El detalle de préstamo ' || v_id_pd || ' no existe o está inactivo',
                'registro', NULL
            );
        END IF;

        IF v_id_cliente_pd <> p_id_cliente THEN
            RETURN json_build_object(
                'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece al cliente del recojo',
                'registro', NULL
            );
        END IF;

        IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_prestamo_detalle
            WHERE id = v_id_pd AND id_prestamo = p_id_prestamo AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle ' || v_id_pd || ' no pertenece al préstamo indicado',
                'registro', NULL
            );
        END IF;

        IF v_fecha_dev IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'El detalle de préstamo ' || v_id_pd || ' ya fue devuelto',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_recojo_detalle rd
            INNER JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
            INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
            WHERE rd.id_prestamo_detalle = v_id_pd
              AND rd.estado = 1
              AND er.nombre IN ('PROGRAMADO', 'EN_RUTA')
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle ' || v_id_pd || ' ya tiene un recojo pendiente',
                'registro', NULL
            );
        END IF;

        INSERT INTO bal_recojo_detalle (
            id_recojo, id_prestamo_detalle, observacion,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id, v_id_pd, v_obs,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        );

        IF v_id_balon IS NOT NULL AND v_id_estado_por_recoger IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_por_recoger,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1;
        END IF;
    END LOOP;

    RETURN bal_obtener_recojo(v_id);
END;
$function$;
