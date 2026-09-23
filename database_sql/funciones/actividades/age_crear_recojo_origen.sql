-- Function: age_crear_recojo_origen
-- Synced from migracion 20260909_age_crear_recojo_hora_inicio.sql
--
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- un recojo ES una actividad. El módulo Balones > Recojos (bal_recojo) se
-- retiró y con él el candado recíproco: la única forma de programar el recojo
-- de un préstamo o alquiler es esta función (idempotente por origen vigente).

DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, integer, character varying, integer);
DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, time without time zone, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_hora_inicio_estimada time without time zone DEFAULT NULL::time without time zone,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_ids_balones integer[] DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo_origen   VARCHAR := UPPER(TRIM(COALESCE(p_tipo_origen, '')));
    v_id_existente  INTEGER;
    v_id_tipo       INTEGER;
    v_id_estado     INTEGER;
    v_id_prioridad  INTEGER;
    v_id_origen_cat INTEGER;
    v_id_actividad  INTEGER;
    v_id_cliente    INTEGER;
    v_numero        VARCHAR;
    v_nombre_cli    VARCHAR;
    v_fecha_pactada DATE;
    v_titulo        VARCHAR;
    v_descripcion   VARCHAR;
    v_balones integer[];
    v_balon integer;
    v_items integer := 0;
    v_pendiente integer;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF v_tipo_origen NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN json_build_object('error', 'tipoOrigen debe ser PRESTAMO o ALQUILER', 'registro', NULL);
    END IF;

    IF p_id_origen IS NULL THEN
        RETURN json_build_object('error', 'idOrigen es obligatorio', 'registro', NULL);
    END IF;

    IF p_hora_inicio_estimada IS NULL THEN
        RETURN json_build_object('error', 'La hora de inicio es obligatoria', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoActividad' AND lo.nombre = 'RECOJO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoActividad' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_tipo IS NULL OR v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Faltan catálogos TipoActividad/EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_prioridad
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PrioridadActividad' AND lo.nombre = 'ALTA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_origen_cat
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = v_tipo_origen AND lo.estado = 1 LIMIT 1;

    PERFORM pg_advisory_xact_lock(hashtext('recojo:' || v_tipo_origen), p_id_origen);

    IF v_tipo_origen = 'PRESTAMO' THEN
        SELECT p.id_cliente, p.numero_prestamo, p.fecha_retorno_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_prestamo p
        LEFT JOIN cli_clientes cli ON cli.id = p.id_cliente
        WHERE p.id = p_id_origen AND p.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El préstamo no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT a.id INTO v_id_existente
        FROM age_actividad a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_prestamo = p_id_origen
          AND a.estado = 1
          AND a.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY a.id DESC
        LIMIT 1;

        v_titulo := format('Recojo préstamo %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de cilindros de %s', COALESCE(v_nombre_cli, 'cliente'));
    ELSE
        SELECT a.id_cliente, a.numero_alquiler, a.fecha_fin_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_alquiler a
        LEFT JOIN cli_clientes cli ON cli.id = a.id_cliente
        WHERE a.id = p_id_origen AND a.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El alquiler no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT act.id INTO v_id_existente
        FROM age_actividad act
        JOIN gen_lista_opciones ea ON ea.id = act.id_estado_actividad
        WHERE act.id_alquiler = p_id_origen
          AND act.estado = 1
          AND act.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY act.id DESC
        LIMIT 1;

        v_titulo := format('Recojo alquiler %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de alquiler de %s', COALESCE(v_nombre_cli, 'cliente'));
    END IF;

    IF v_id_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('id', v_id_existente, 'creada', FALSE, 'items', 0)
        );
    END IF;

    IF v_tipo_origen = 'PRESTAMO' THEN
        -- Bloquear en orden fijo impide reservar el mismo balón desde dos préstamos.
        FOR v_balon IN SELECT DISTINCT pd.id_balon FROM bal_prestamo_detalle pd
            WHERE pd.id_prestamo = p_id_origen AND pd.estado = 1 AND pd.id_balon IS NOT NULL ORDER BY pd.id_balon
        LOOP
            PERFORM pg_advisory_xact_lock(hashtext('recojo:balon'), v_balon);
            PERFORM 1 FROM bal_balon WHERE id = v_balon FOR UPDATE;
        END LOOP;
        SELECT array_agg(x.id_balon ORDER BY x.id_balon) INTO v_balones
        FROM age_balones_disponibles_recojo(p_id_origen) x;
        IF COALESCE(cardinality(v_balones), 0) = 0 THEN
            RETURN json_build_object('error', 'No hay balones entregados pendientes de devolución y disponibles para recojo', 'registro', NULL);
        END IF;
        IF p_ids_balones IS NOT NULL THEN
            IF cardinality(p_ids_balones) = 0 OR array_position(p_ids_balones, NULL) IS NOT NULL OR NOT p_ids_balones <@ v_balones THEN
                RETURN json_build_object('error', 'Selecciona únicamente balones entregados, pendientes y sin otro recojo activo', 'registro', NULL);
            END IF;
            v_balones := ARRAY(SELECT DISTINCT unnest(p_ids_balones));
        END IF;
    ELSE
        IF NOT EXISTS (SELECT 1 FROM bal_alquiler WHERE id = p_id_origen AND estado = 1
            AND fecha_fin_real IS NULL AND fecha_devolucion_regulador IS NULL
            AND COALESCE(id_producto_regulador, id_producto_stock) IS NOT NULL) THEN
            RETURN json_build_object('error', 'El alquiler no tiene accesorios pendientes de devolución', 'registro', NULL);
        END IF;
        IF p_ids_balones IS NOT NULL THEN
            RETURN json_build_object('error', 'Los balones se recogen desde un préstamo', 'registro', NULL);
        END IF;
    END IF;
    IF p_id_trabajador_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador_responsable AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El responsable debe ser un trabajador vigente', 'registro', NULL);
    END IF;
    SELECT lo.id INTO v_pendiente FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;
    IF v_pendiente IS NULL THEN
        RETURN json_build_object('error', 'Falta el estado de verificación PENDIENTE', 'registro', NULL);
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada, hora_inicio_estimada,
        id_tipo_actividad, id_prioridad,
        id_cliente, id_trabajador_responsable, id_estado_actividad, observaciones,
        id_prestamo, id_alquiler, id_tipo_origen,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        v_titulo, v_descripcion,
        COALESCE(p_fecha_programada, v_fecha_pactada, CURRENT_DATE),
        p_hora_inicio_estimada,
        v_id_tipo, v_id_prioridad,
        v_id_cliente, p_id_trabajador_responsable, v_id_estado, p_observaciones,
        CASE WHEN v_tipo_origen = 'PRESTAMO' THEN p_id_origen ELSE NULL END,
        CASE WHEN v_tipo_origen = 'ALQUILER' THEN p_id_origen ELSE NULL END,
        v_id_origen_cat,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_actividad;

    IF v_tipo_origen = 'PRESTAMO' THEN
        INSERT INTO age_actividad_item (id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion)
        SELECT v_id_actividad, ROW_NUMBER() OVER (ORDER BY pd.id), COALESCE(pd.id_producto, b.id_producto_gas),
            b.codigo_balon, 1, b.id, pd.id, v_pendiente, v_pendiente, p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM bal_prestamo_detalle pd JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.id_prestamo = p_id_origen AND pd.estado = 1 AND pd.rol = 'ENTREGADO'
            AND pd.fecha_devolucion IS NULL AND pd.id_balon = ANY(v_balones);
        GET DIAGNOSTICS v_items = ROW_COUNT;
        IF v_items <> cardinality(v_balones) THEN
            RAISE EXCEPTION 'No se pudo reservar exactamente la selección de balones. Revisa el préstamo.';
        END IF;
    END IF;
    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', v_items)
    );
END;
$function$;
