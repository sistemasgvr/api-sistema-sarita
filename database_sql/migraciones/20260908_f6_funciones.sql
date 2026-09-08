-- ============================================================
-- Migración: Fase 6 — funciones de verificación, recojo y ranking
-- Fecha: 2026-09-08
--
-- Requiere 20260908_f6_verificacion_escaneo.sql (catálogos, columnas y tabla
-- de bitácora).
--
--   · age_registrar_verificacion    — escaneo en salida y llegada (8.b.i.3)
--   · age_crear_recojo_prestamo     — recojo desde un préstamo (8.b.i.4)
--   · age_generar_recojos_por_vencer— job de auto-registro (8.b.i.5)
--   · age_ranking_usuarios          — ranking por colaborador (8.b.i.6)
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260908_f6_funciones.sql
-- ============================================================



-- ============================================================
-- database_sql/funciones/actividades/age_registrar_verificacion.sql
-- ============================================================

-- Function: age_registrar_verificacion
-- Fase 6 (apunte 8.b.i.3) — verificación por escaneo de los ítems de una actividad.
--
-- Recibe los códigos leídos con la pistola y, para cada uno, busca el ítem cuyo
-- cilindro o producto le corresponde. Lo que no coincide se registra igual en la
-- bitácora con coincide = FALSE: saber que se escaneó algo ajeno es información,
-- no ruido que convenga descartar.
--
-- p_momento: 'SALIDA' | 'LLEGADA'.
-- p_codigos: ["BAL-OXM10-001", ...]
-- Los ítems no escaneados quedan como estaban (PENDIENTE si nunca se tocaron).
DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json DEFAULT NULL::json, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_momento        VARCHAR;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_codigo         VARCHAR;
    v_id_item        INTEGER;
    v_coincidencias  INTEGER := 0;
    v_ajenos         INTEGER := 0;
    v_no_escaneados  INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_momento := UPPER(TRIM(COALESCE(p_momento, '')));

    IF v_momento NOT IN ('SALIDA', 'LLEGADA') THEN
        RETURN json_build_object('error', 'El momento debe ser SALIDA o LLEGADA', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id_actividad AND estado = 1) THEN
        RETURN json_build_object('error', 'La actividad no existe o está anulada', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    IF v_id_ok IS NULL THEN
        RETURN json_build_object('error', 'Falta el catálogo EstadoVerificacionItem', 'registro', NULL);
    END IF;

    FOR v_codigo IN
        SELECT DISTINCT UPPER(TRIM(x#>>'{}'))
        FROM json_array_elements(COALESCE(p_codigos, '[]'::JSON)) AS a(x)
        WHERE NULLIF(TRIM(x#>>'{}'), '') IS NOT NULL
    LOOP
        -- Se busca por código de cilindro y, si no, por código de producto: en
        -- una entrega pueden viajar accesorios que no son balones.
        SELECT ai.id INTO v_id_item
        FROM age_actividad_item ai
        LEFT JOIN bal_balon b ON b.id = ai.id_balon
        LEFT JOIN pro_producto p ON p.id = ai.id_producto
        WHERE ai.id_actividad = p_id_actividad
          AND ai.estado = 1
          AND (
              UPPER(TRIM(COALESCE(b.codigo_balon, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(b.numero_serie, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(p.codigo, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(p.codigo_barra, ''))) = v_codigo
          )
        ORDER BY ai.item
        LIMIT 1;

        INSERT INTO age_actividad_verificacion (
            id_actividad, id_actividad_item, momento, codigo_escaneado, coincide,
            observacion, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            p_id_actividad, v_id_item, v_momento, v_codigo, v_id_item IS NOT NULL,
            p_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
        );

        IF v_id_item IS NOT NULL THEN
            IF v_momento = 'SALIDA' THEN
                UPDATE age_actividad_item
                SET id_estado_verificacion_salida =
                        CASE WHEN NULLIF(TRIM(COALESCE(p_observacion, '')), '') IS NULL
                             THEN v_id_ok ELSE COALESCE(v_id_observado, v_id_ok) END,
                    observacion_salida = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion_salida),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            ELSE
                UPDATE age_actividad_item
                SET id_estado_verificacion_llegada =
                        CASE WHEN NULLIF(TRIM(COALESCE(p_observacion, '')), '') IS NULL
                             THEN v_id_ok ELSE COALESCE(v_id_observado, v_id_ok) END,
                    observacion_llegada = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion_llegada),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            END IF;
            v_coincidencias := v_coincidencias + 1;
        ELSE
            v_ajenos := v_ajenos + 1;
        END IF;

        v_id_item := NULL;
    END LOOP;

    -- Cuántos quedan sin verificar en este momento: es el dato que decide si la
    -- salida puede darse por cerrada.
    SELECT COUNT(*)::INT INTO v_no_escaneados
    FROM age_actividad_item ai
    JOIN gen_lista_opciones lo
      ON lo.id = CASE WHEN v_momento = 'SALIDA'
                      THEN ai.id_estado_verificacion_salida
                      ELSE ai.id_estado_verificacion_llegada END
    WHERE ai.id_actividad = p_id_actividad
      AND ai.estado = 1
      AND lo.nombre = 'PENDIENTE';

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'momento', v_momento,
            'coincidencias', v_coincidencias,
            'no_pertenecen', v_ajenos,
            'pendientes', v_no_escaneados,
            'completo', v_no_escaneados = 0
        )
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_crear_recojo_prestamo.sql
-- ============================================================

-- Function: age_crear_recojo_prestamo
-- Fase 6 (apuntes 8.b.i.4 y 8.b.i.5) — actividad de recojo a partir de un préstamo.
--
-- Los ítems salen del detalle del préstamo, no se re-teclean: un recojo es ir a
-- buscar exactamente los cilindros que se entregaron y siguen fuera.
--
-- Es idempotente por préstamo: si ya hay una actividad de recojo abierta para
-- ese préstamo devuelve la existente. Así el job programado puede correr todos
-- los días sin llenar la agenda de duplicados.
DROP FUNCTION IF EXISTS age_crear_recojo_prestamo(p_id_prestamo integer, p_fecha_programada date, p_id_trabajador_responsable integer, p_observaciones character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_prestamo(p_id_prestamo integer, p_fecha_programada date DEFAULT NULL::date, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo      RECORD;
    v_id_existente  INTEGER;
    v_id_tipo       INTEGER;
    v_id_estado     INTEGER;
    v_id_prioridad  INTEGER;
    v_id_origen     INTEGER;
    v_id_pendiente  INTEGER;
    v_id_actividad  INTEGER;
    v_items         INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.id, p.numero_prestamo, p.id_cliente, p.fecha_retorno_pactada,
           COALESCE(
               NULLIF(TRIM(cli.razon_social), ''),
               NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
               cli.numero_documento
           ) AS nombre_cliente
    INTO v_prestamo
    FROM bal_prestamo p
    LEFT JOIN cli_clientes cli ON cli.id = p.id_cliente
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF v_prestamo.id IS NULL THEN
        RETURN json_build_object('error', 'El préstamo no existe o está anulado', 'registro', NULL);
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

    -- Ya hay un recojo abierto para este préstamo: no se duplica.
    SELECT a.id INTO v_id_existente
    FROM age_actividad a
    JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id_prestamo = p_id_prestamo
      AND a.estado = 1
      AND a.id_tipo_actividad = v_id_tipo
      AND ea.nombre = 'PENDIENTE'
    ORDER BY a.id DESC
    LIMIT 1;

    IF v_id_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('id', v_id_existente, 'creada', FALSE, 'items', 0)
        );
    END IF;

    SELECT lo.id INTO v_id_prioridad
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PrioridadActividad' AND lo.nombre = 'ALTA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_origen
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = 'PRESTAMO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada, id_tipo_actividad, id_prioridad,
        id_cliente, id_trabajador_responsable, id_estado_actividad, observaciones,
        id_prestamo, id_tipo_origen, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        format('Recojo préstamo %s', COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::TEXT)),
        format('Recojo de cilindros de %s', COALESCE(v_prestamo.nombre_cliente, 'cliente')),
        COALESCE(p_fecha_programada, v_prestamo.fecha_retorno_pactada, CURRENT_DATE),
        v_id_tipo, v_id_prioridad,
        v_prestamo.id_cliente, p_id_trabajador_responsable, v_id_estado, p_observaciones,
        p_id_prestamo, v_id_origen, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_actividad;

    -- Solo los cilindros que siguen fuera: los ya devueltos no se van a recoger.
    INSERT INTO age_actividad_item (
        id_actividad, item, id_producto, descripcion, cantidad, id_balon,
        id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
        id_usuario_creacion, id_usuario_modificacion
    )
    SELECT
        v_id_actividad,
        ROW_NUMBER() OVER (ORDER BY pd.id),
        COALESCE(pd.id_producto, b.id_producto_gas),
        COALESCE(b.codigo_balon, 'Cilindro'),
        1,
        pd.id_balon,
        pd.id,
        v_id_pendiente,
        v_id_pendiente,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM bal_prestamo_detalle pd
    LEFT JOIN bal_balon b ON b.id = pd.id_balon
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
      AND pd.id_balon IS NOT NULL;

    GET DIAGNOSTICS v_items = ROW_COUNT;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', v_items)
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_generar_recojos_por_vencer.sql
-- ============================================================

-- Function: age_generar_recojos_por_vencer
-- Fase 6 (apunte 8.b.i.5) — auto-registro de la actividad de recojo.
--
-- Recorre los préstamos cuyo retorno pactado cae dentro de la ventana y crea su
-- actividad de recojo. Se apoya en age_crear_recojo_prestamo, que es idempotente
-- por préstamo, así que correrlo a diario no genera duplicados.
--
-- p_dias_antes: ventana hacia adelante. 0 = solo los ya vencidos.
--   El valor operativo lo decide el negocio (decisión 12 del plan); mientras no
--   esté fijado, quien llama al job pasa el que quiera y el default es 3.
-- p_id_trabajador_responsable: a quién se asigna. NULL = sin asignar, para que
--   el encargado reparta desde la agenda.
DROP FUNCTION IF EXISTS age_generar_recojos_por_vencer(p_dias_antes integer, p_id_trabajador_responsable integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_generar_recojos_por_vencer(p_dias_antes integer DEFAULT 3, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo   RECORD;
    v_res        JSON;
    v_creadas    INTEGER := 0;
    v_existentes INTEGER := 0;
    v_ids        INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    FOR v_prestamo IN
        SELECT DISTINCT p.id, p.fecha_retorno_pactada
        FROM bal_prestamo p
        JOIN bal_prestamo_detalle pd
          ON pd.id_prestamo = p.id
         AND pd.estado = 1
         AND pd.fecha_devolucion IS NULL
         AND pd.id_balon IS NOT NULL
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada <= CURRENT_DATE + GREATEST(COALESCE(p_dias_antes, 3), 0)
          AND COALESCE(ep.nombre, '') NOT IN ('CERRADO', 'CANCELADO', 'DEVUELTO')
        ORDER BY p.fecha_retorno_pactada
    LOOP
        v_res := age_crear_recojo_prestamo(
            p_id_prestamo               => v_prestamo.id,
            p_fecha_programada          => v_prestamo.fecha_retorno_pactada,
            p_id_trabajador_responsable => p_id_trabajador_responsable,
            p_observaciones             => 'Generada automáticamente por vencimiento del préstamo',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            -- Un préstamo con datos inconsistentes no debe frenar al resto.
            CONTINUE;
        END IF;

        IF (v_res->'registro'->>'creada')::BOOLEAN THEN
            v_creadas := v_creadas + 1;
            v_ids := v_ids || (v_res->'registro'->>'id')::INTEGER;
        ELSE
            v_existentes := v_existentes + 1;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'dias_antes', GREATEST(COALESCE(p_dias_antes, 3), 0),
            'creadas', v_creadas,
            'ya_existian', v_existentes,
            'id_actividades', array_to_json(v_ids)
        )
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_ranking_usuarios.sql
-- ============================================================

-- Function: age_ranking_usuarios
-- Fase 6 (apunte 8.b.i.6) — ranking de colaboradores por actividades en un rango.
--
-- Cuenta por responsable, no por quien creó el registro: lo que interesa medir
-- es quién sale a hacer el trabajo, no quién lo tipeó en el sistema.
DROP FUNCTION IF EXISTS age_ranking_usuarios(p_fecha_desde date, p_fecha_hasta date, p_limite integer);

CREATE OR REPLACE FUNCTION age_ranking_usuarios(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_limite integer DEFAULT 20)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM age_actividad a
    WHERE a.estado = 1
      AND (p_fecha_desde IS NULL OR a.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR a.fecha_programada <= p_fecha_hasta);

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total DESC, t.nombre), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            COALESCE(a.id_trabajador_responsable, a.id_usuario_responsable) AS id_responsable,
            COALESCE(
                NULLIF(TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)), ''),
                u.nombre,
                'Sin responsable'
            ) AS nombre,
            COUNT(*)::INT AS total,
            COUNT(*) FILTER (WHERE ea.nombre = 'REALIZADA')::INT AS realizadas,
            COUNT(*) FILTER (WHERE ea.nombre = 'PENDIENTE')::INT AS pendientes,
            COUNT(*) FILTER (WHERE ea.nombre = 'CANCELADA')::INT AS canceladas,
            COUNT(*) FILTER (WHERE ta.nombre = 'REPARTO')::INT AS repartos,
            COUNT(*) FILTER (WHERE ta.nombre = 'RECOJO')::INT AS recojos
        FROM age_actividad a
        LEFT JOIN tra_trabajadores tr ON tr.id = a.id_trabajador_responsable
        LEFT JOIN auth_usuarios u ON u.id = a.id_usuario_responsable
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        WHERE a.estado = 1
          AND (p_fecha_desde IS NULL OR a.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR a.fecha_programada <= p_fecha_hasta)
        GROUP BY 1, 2
        ORDER BY total DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
