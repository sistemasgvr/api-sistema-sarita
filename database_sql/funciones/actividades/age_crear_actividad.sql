DROP FUNCTION IF EXISTS age_crear_actividad(
    VARCHAR, TEXT, DATE, TIME, TIME, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, VARCHAR, INTEGER
);
DROP FUNCTION IF EXISTS age_crear_actividad(
    VARCHAR, TEXT, DATE, TIME, TIME, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, VARCHAR, INTEGER, INTEGER, INTEGER, JSON
);

CREATE OR REPLACE FUNCTION age_crear_actividad(
    p_titulo VARCHAR,
    p_descripcion TEXT,
    p_fecha_programada DATE,
    p_hora_inicio_estimada TIME,
    p_hora_fin_estimada TIME,
    p_id_tipo_actividad INTEGER,
    p_id_prioridad INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_id_estado_actividad INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_chofer_responsable INTEGER DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_items JSON DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_tipo VARCHAR;
    v_cliente INTEGER;
    v_titulo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_cliente := p_id_cliente;
    v_titulo := NULLIF(TRIM(COALESCE(p_titulo, '')), '');

    IF p_id_comprobante IS NOT NULL THEN
        SELECT vc.id_cliente, vc.serie, vc.numero
        INTO v_cliente, v_serie, v_numero
        FROM ven_comprobante vc
        WHERE vc.id = p_id_comprobante AND vc.estado = 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El comprobante indicado no existe.';
        END IF;

        v_cliente := COALESCE(p_id_cliente, v_cliente);
        IF v_titulo IS NULL THEN
            v_titulo := TRIM(CONCAT('Reparto ', COALESCE(v_serie, ''), '-', COALESCE(v_numero, '')));
        END IF;

        IF EXISTS (
            SELECT 1
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_comprobante = p_id_comprobante
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
        ) THEN
            RAISE EXCEPTION 'Este comprobante ya tiene un reparto / actividad vigente.';
        END IF;
    END IF;

    IF v_titulo IS NULL THEN
        RAISE EXCEPTION 'El título es obligatorio.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_tipo_actividad
          AND o.estado = 1
          AND (l.nombre = 'TipoActividad' OR l.id = 48)
    ) THEN
        RAISE EXCEPTION 'El tipo de actividad indicado no es válido.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_prioridad
          AND o.estado = 1
          AND (l.nombre = 'PrioridadActividad' OR l.id = 50)
    ) THEN
        RAISE EXCEPTION 'La prioridad indicada no es válida.';
    END IF;

    IF p_id_estado_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_estado_actividad
          AND o.estado = 1
          AND (l.nombre = 'EstadoActividad' OR l.id = 49)
    ) THEN
        RAISE EXCEPTION 'El estado de actividad indicado no es válido.';
    END IF;

    IF p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF p_hora_inicio_estimada >= p_hora_fin_estimada THEN
            RAISE EXCEPTION 'La hora de inicio estimada debe ser menor a la hora de fin estimada.';
        END IF;
    END IF;

    SELECT UPPER(TRIM(nombre)) INTO v_tipo
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_actividad;

    IF v_tipo = 'REPARTO' THEN
        IF p_id_chofer_responsable IS NULL THEN
            RAISE EXCEPTION 'El reparto requiere un chofer / repartidor de flota propia.';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM gen_chofer
            WHERE id = p_id_chofer_responsable AND estado = 1 AND id_cliente IS NULL
        ) THEN
            RAISE EXCEPTION 'El chofer debe ser de flota propia (repartidor).';
        END IF;
    END IF;

    IF p_id_usuario_responsable IS NOT NULL AND p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM age_actividad
            WHERE id_usuario_responsable = p_id_usuario_responsable
              AND fecha_programada = p_fecha_programada
              AND estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM gen_lista_opciones ea
                  WHERE ea.id = age_actividad.id_estado_actividad
                    AND UPPER(TRIM(ea.nombre)) IN ('CANCELADA', 'CANCELADO')
              )
              AND (
                  (p_hora_inicio_estimada >= hora_inicio_estimada AND p_hora_inicio_estimada < hora_fin_estimada)
                  OR (p_hora_fin_estimada > hora_inicio_estimada AND p_hora_fin_estimada <= hora_fin_estimada)
                  OR (p_hora_inicio_estimada <= hora_inicio_estimada AND p_hora_fin_estimada >= hora_fin_estimada)
              )
        ) THEN
            RAISE EXCEPTION 'El usuario responsable ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.';
        END IF;
    END IF;

    IF p_id_chofer_responsable IS NOT NULL AND p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM age_actividad
            WHERE id_chofer_responsable = p_id_chofer_responsable
              AND fecha_programada = p_fecha_programada
              AND estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM gen_lista_opciones ea
                  WHERE ea.id = age_actividad.id_estado_actividad
                    AND UPPER(TRIM(ea.nombre)) IN ('CANCELADA', 'CANCELADO')
              )
              AND (
                  (p_hora_inicio_estimada >= hora_inicio_estimada AND p_hora_inicio_estimada < hora_fin_estimada)
                  OR (p_hora_fin_estimada > hora_inicio_estimada AND p_hora_fin_estimada <= hora_fin_estimada)
                  OR (p_hora_inicio_estimada <= hora_inicio_estimada AND p_hora_fin_estimada >= hora_fin_estimada)
              )
        ) THEN
            RAISE EXCEPTION 'El chofer ya tiene otra actividad asignada que se cruza en ese horario.';
        END IF;
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada,
        hora_inicio_estimada, hora_fin_estimada,
        id_tipo_actividad, id_prioridad, id_cliente,
        id_usuario_responsable, id_chofer_responsable, id_comprobante,
        id_estado_actividad, observaciones,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_titulo, p_descripcion, p_fecha_programada,
        p_hora_inicio_estimada, p_hora_fin_estimada,
        p_id_tipo_actividad, p_id_prioridad, v_cliente,
        p_id_usuario_responsable, p_id_chofer_responsable, p_id_comprobante,
        p_id_estado_actividad, p_observaciones,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_items IS NOT NULL AND json_typeof(p_items) = 'array' THEN
        FOR v_item IN SELECT value FROM json_array_elements(p_items)
        LOOP
            v_n := v_n + 1;
            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                COALESCE((v_item->>'item')::INTEGER, v_n),
                COALESCE((v_item->>'idProducto')::INTEGER, (v_item->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
                COALESCE((v_item->>'cantidad')::NUMERIC, 1),
                COALESCE((v_item->>'idBalon')::INTEGER, (v_item->>'id_balon')::INTEGER),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    ELSIF p_id_comprobante IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            v_id,
            d.item,
            d.id_producto,
            NULLIF(TRIM(COALESCE(d.descripcion, p.nombre, '')), ''),
            d.cantidad,
            d.id_balon,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.id_comprobante = p_id_comprobante AND d.estado = 1
        ORDER BY d.item;
    END IF;

    RETURN age_obtener_actividad(v_id);
END;
$function$;
