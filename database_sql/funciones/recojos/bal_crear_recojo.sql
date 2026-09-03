-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer, p_id_alquiler integer, p_id_recarga_planta integer, p_fecha_programada date, p_hora_estimada time without time zone, p_id_usuario_responsable integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_marcar_balon_por_recoger boolean);

CREATE OR REPLACE FUNCTION bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_id_recarga_planta integer DEFAULT NULL::integer, p_fecha_programada date DEFAULT NULL::date, p_hora_estimada time without time zone DEFAULT NULL::time without time zone, p_id_usuario_responsable integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_marcar_balon_por_recoger boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_estado INTEGER;
    v_por_recoger INTEGER;
    x JSONB;
    v_pd INTEGER;
    v_ad INTEGER;
    v_b INTEGER;
    v_balon INTEGER;
    v_cliente INTEGER;
    v_dev DATE;
    v_len INTEGER;
    v_producto INTEGER;
    v_id_recarga_planta INTEGER;
    v_proveedor INTEGER;
    v_rp_estado VARCHAR;
    v_id_estado_balon_local INTEGER;
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

    -- Validación de origen recarga en planta: el "cliente" del recojo es el proveedor
    IF p_id_recarga_planta IS NOT NULL THEN
        SELECT rp.id_proveedor, est.nombre
        INTO v_proveedor, v_rp_estado
        FROM doc_salida rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

        IF v_proveedor IS NULL THEN
            RETURN json_build_object(
                'error', 'Orden de recarga en planta no encontrada',
                'registro', NULL
            );
        END IF;

        IF v_rp_estado NOT IN ('ENVIADO', 'CERRADO') THEN
            RETURN json_build_object(
                'error', 'La orden de recarga en planta aún no ha sido enviada',
                'registro', NULL
            );
        END IF;

        IF v_proveedor <> p_id_cliente THEN
            RETURN json_build_object(
                'error', 'El cliente del recojo debe coincidir con el proveedor de la recarga',
                'registro', NULL
            );
        END IF;

        IF v_len = 0 THEN
            RETURN json_build_object(
                'error', 'El recojo de recarga en planta requiere al menos un cilindro',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Recojo sin cilindros: solo alquiler de regulador/accesorio
    IF v_len = 0 THEN
        IF p_id_alquiler IS NULL OR p_id_prestamo IS NOT NULL OR p_id_recarga_planta IS NOT NULL THEN
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
        id_doc_salida,
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
        p_id_recarga_planta,
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
        v_b := COALESCE(
            NULLIF(x->>'idBalon', '')::INTEGER,
            NULLIF(x->>'id_balon', '')::INTEGER
        );

        IF (v_pd IS NOT NULL)::INTEGER + (v_ad IS NOT NULL)::INTEGER + (v_b IS NOT NULL)::INTEGER <> 1 THEN
            RAISE EXCEPTION 'Cada detalle debe tener exactamente un origen (préstamo, alquiler o balón)';
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

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSIF v_ad IS NOT NULL THEN
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

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSE
            -- Origen recarga en planta externa: el balón permanece EN_RECARGA_EXTERNA
            -- hasta que se cierra el recojo (distribución manual de gas).
            IF p_id_recarga_planta IS NULL THEN
                RAISE EXCEPTION 'El detalle por balón requiere el documento de salida de la recarga';
            END IF;

            SELECT b.id, b.id_estado_balon
            INTO v_balon, v_id_estado_balon_local
            FROM bal_balon b
            WHERE b.id = v_b AND b.estado = 1;

            IF v_balon IS NULL THEN
                RAISE EXCEPTION 'Balón % no encontrado', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM doc_salida_detalle d
                WHERE d.id_doc_salida = p_id_recarga_planta
                  AND d.id_balon = v_b
                  AND d.estado = 1
            ) THEN
                RAISE EXCEPTION 'El balón % no pertenece a la orden de recarga en planta', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM bal_balon b
                JOIN gen_lista_opciones e ON e.id = b.id_estado_balon
                WHERE b.id = v_b AND b.estado = 1 AND e.nombre = 'EN_RECARGA_EXTERNA'
            ) THEN
                RAISE EXCEPTION 'El balón % no está en estado EN_RECARGA_EXTERNA', v_b;
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_balon = v_b
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El balón % ya tiene un recojo programado', v_b;
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_balon,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_b,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
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
