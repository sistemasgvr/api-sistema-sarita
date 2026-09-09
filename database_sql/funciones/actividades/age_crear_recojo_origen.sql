-- Function: age_crear_recojo_origen
-- Synced from migracion 20260909_age_crear_recojo_hora_inicio.sql

DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, integer, character varying, integer);
DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, time without time zone, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_hora_inicio_estimada time without time zone DEFAULT NULL::time without time zone,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
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

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', 0)
    );
END;
$function$;
