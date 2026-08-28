CREATE OR REPLACE FUNCTION bal_crear_recojo(
    p_id_cliente INTEGER,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_alquiler INTEGER DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_estimada TIME DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_marcar_balon_por_recoger BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_estado INTEGER;
    v_por_recoger INTEGER;
    x JSONB;
    v_pd INTEGER;
    v_ad INTEGER;
    v_balon INTEGER;
    v_cliente INTEGER;
    v_dev DATE;
    v_len INTEGER;
    v_producto INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_len := jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB));

    IF p_id_cliente IS NULL OR p_fecha_programada IS NULL THEN
        RETURN json_build_object(
            'error', 'Cliente y fecha son obligatorios',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'Cliente inválido', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
        WHERE p.id = p_id_prestamo
          AND p.id_cliente = p_id_cliente
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Préstamo activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
        WHERE a.id = p_id_alquiler
          AND a.id_cliente = p_id_cliente
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Alquiler activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    -- Recojo sin cilindros: solo alquiler de regulador/accesorio
    IF v_len = 0 THEN
        IF p_id_alquiler IS NULL OR p_id_prestamo IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'Cliente, fecha y detalles son obligatorios',
                'registro', NULL
            );
        END IF;

        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock)
        INTO v_producto
        FROM bal_alquiler a
        WHERE a.id = p_id_alquiler AND a.estado = 1;

        IF v_producto IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene regulador/accesorio para recojo',
                'registro', NULL
            );
        END IF;

        -- Permitido con o sin cilindros pendientes: visita solo de regulador/accesorio

        IF EXISTS (
            SELECT 1
            FROM bal_recojo r
            JOIN gen_lista_opciones e ON e.id = r.id_estado
            WHERE r.id_alquiler = p_id_alquiler
              AND r.estado = 1
              AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
        ) THEN
            RETURN json_build_object(
                'error', 'El alquiler ya tiene un recojo programado o en ruta',
                'registro', NULL
            );
        END IF;
    END IF;

    SELECT lo.id INTO v_estado
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = 'PROGRAMADO' AND lo.estado = 1;

    SELECT lo.id INTO v_por_recoger
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'POR_RECOGER' AND lo.estado = 1;

    INSERT INTO bal_recojo (
        id_cliente,
        id_prestamo,
        id_alquiler,
        fecha_programada,
        hora_estimada,
        id_usuario_responsable,
        id_estado,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        p_id_alquiler,
        p_fecha_programada,
        p_hora_estimada,
        p_id_usuario_responsable,
        v_estado,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR x IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles::JSONB, '[]'::JSONB))
    LOOP
        v_pd := COALESCE(
            NULLIF(x->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(x->>'id_prestamo_detalle', '')::INTEGER
        );
        v_ad := COALESCE(
            NULLIF(x->>'idAlquilerDetalle', '')::INTEGER,
            NULLIF(x->>'id_alquiler_detalle', '')::INTEGER
        );

        IF (v_pd IS NOT NULL)::INTEGER + (v_ad IS NOT NULL)::INTEGER <> 1 THEN
            RAISE EXCEPTION 'Cada detalle debe tener exactamente un origen';
        END IF;

        IF v_pd IS NOT NULL THEN
            SELECT pd.id_balon, p.id_cliente, pd.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_prestamo_detalle pd
            JOIN bal_prestamo p ON p.id = pd.id_prestamo
            JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
            WHERE pd.id = v_pd AND pd.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_prestamo IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_prestamo_detalle
                       WHERE id = v_pd AND id_prestamo = p_id_prestamo
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de préstamo inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_prestamo_detalle = v_pd
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de préstamo ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_prestamo_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_pd,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        ELSE
            SELECT ad.id_balon, a.id_cliente, ad.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_alquiler_detalle ad
            JOIN bal_alquiler a ON a.id = ad.id_alquiler
            JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
            WHERE ad.id = v_ad AND ad.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_alquiler IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_alquiler_detalle
                       WHERE id = v_ad AND id_alquiler = p_id_alquiler
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de alquiler inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_alquiler_detalle = v_ad
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de alquiler ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_alquiler_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_ad,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END IF;

        IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_por_recoger,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_balon AND estado = 1;
        END IF;
    END LOOP;

    RETURN bal_obtener_recojo(v_id);
EXCEPTION
    WHEN OTHERS THEN
        IF v_id IS NOT NULL THEN
            DELETE FROM bal_recojo WHERE id = v_id;
        END IF;
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;
