-- ============================================================
-- Migración: un recojo ES una actividad — retiro del módulo Balones > Recojos
-- Fecha: 2026-09-11
--
-- El recojo de cilindros en préstamo y de accesorios en alquiler se agenda,
-- se ejecuta (iniciar → verificar llegada → culminar con almacén destino) y
-- se cierra ÚNICAMENTE en operativa/actividades (age_*). Existían dos caminos
-- (bal_recojo y age_actividad RECOJO) con un candado para que no convivieran;
-- desde esta migración solo queda el de actividades.
--
-- Qué cambia
--  1) age_cancelar_recojos_pendientes_origen (nueva): cancela la actividad de
--     RECOJO PENDIENTE / PROGRAMADA de un préstamo o alquiler cuando el origen
--     ya no tiene nada que recoger. Reemplaza a bal_actualizar_recojo(CANCELADO).
--  2) age_crear_recojo_origen / age_listar_vencidos_recojo: sin candado ni
--     exclusión por bal_recojo. Y age_listar_vencidos_recojo deja de ser STABLE:
--     con SET TIME ZONE dentro Postgres la rechazaba ("SET is not allowed in a
--     non-volatile function") y además usaba el CTE en dos sentencias; el
--     selector de vencidos del formulario nunca cargó.
--  3) ven_aplicar_efectos_pos: el auto-recojo del préstamo POS crea la
--     actividad RECOJO (fecha = retorno pactado, 08:00, PENDIENTE) en vez de
--     bal_recojo.
--  4) bal_prestamo_cerrar_si_completo: al cerrar el préstamo cancela la
--     actividad pendiente (punto común de mostrador, renovación POS y NC).
--     bal_devolver_prestamo_detalle deja de tocar recojos directamente.
--  5) bal_devolver_alquiler_detalle: al finalizar el alquiler cancela la
--     actividad pendiente.
--  6) bal_devolver_regulador_alquiler pierde p_id_recojo (y con ello
--     bal_mantenimiento.id_recojo); se ajustan age_culminar_recojo,
--     ven_cerrar_custodia_comprobante, bal_listar/obtener_mantenimiento.
--  7) doc_anular_salida y bal_finalizar_recarga_planta: sin bloqueo por recojo
--     de planta (ese camino, bal_generar_recojo_recarga_planta, se retira: el
--     retorno de planta va solo por Finalizar recarga).
--  8) Datos: cada bal_recojo vivo (PROGRAMADO / EN_RUTA) de préstamo o
--     alquiler se convierte en actividad RECOJO pendiente. El historial de
--     visitas NO se migra (decisión del 2026-09-11).
--  9) DROP de las funciones bal_*recojo*, de las tablas bal_recojo_detalle y
--     bal_recojo, de la columna bal_mantenimiento.id_recojo, de los catálogos
--     EstadoRecojo / ResultadoRecojoDetalle / MotivoFalloRecojo y de los
--     permisos recojos_balon.*.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_recojos_solo_actividades.sql
-- ============================================================


-- ===== funciones\actividades\age_cancelar_recojos_pendientes_origen.sql =====
-- Function: age_cancelar_recojos_pendientes_origen
-- Source: migraciones/20260911_recojos_solo_actividades.sql
--
-- Cuando un préstamo se cierra o un alquiler se finaliza por fuera de la
-- agenda (devolución en mostrador, renovación POS), la actividad de RECOJO
-- que seguía PENDIENTE / PROGRAMADA para ese origen ya no tiene qué recoger.
-- Reemplaza lo que hacía bal_actualizar_recojo(CANCELADO) sobre bal_recojo.
--
-- Solo toca PENDIENTE / PROGRAMADA: una EN_RUTA la cierra el chofer con
-- age_culminar_recojo (que es quien devuelve los cilindros y llega aquí a
-- través de bal_devolver_*) o se cancela a mano con age_cancelar_actividad.
-- Devuelve cuántas actividades canceló. Nunca falla por no encontrar nada.

DROP FUNCTION IF EXISTS age_cancelar_recojos_pendientes_origen(character varying, integer, integer, character varying);

CREATE OR REPLACE FUNCTION age_cancelar_recojos_pendientes_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_motivo character varying DEFAULT NULL::character varying
)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo_origen  VARCHAR := UPPER(TRIM(COALESCE(p_tipo_origen, '')));
    v_id_cancelada INTEGER;
    v_motivo       VARCHAR := COALESCE(
        NULLIF(TRIM(p_motivo), ''),
        'Cancelada: el origen ya no tiene cilindros/accesorios pendientes de recojo'
    );
    v_n            INTEGER := 0;
BEGIN
    IF p_id_origen IS NULL OR v_tipo_origen NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN 0;
    END IF;

    SELECT o.id INTO v_id_cancelada
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(o.nombre)) = 'CANCELADA'
      AND o.estado = 1
    LIMIT 1;

    IF v_id_cancelada IS NULL THEN
        RETURN 0;
    END IF;

    UPDATE age_actividad a
    SET id_estado_actividad     = v_id_cancelada,
        fecha_hora_cierre       = NOW(),
        observaciones           = LEFT(
            TRIM(COALESCE(a.observaciones || ' — ', '') || v_motivo), 500
        ),
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, a.id_usuario_modificacion),
        fecha_modificacion      = NOW()
    FROM gen_lista_opciones ta, gen_lista_opciones ea
    WHERE ta.id = a.id_tipo_actividad
      AND ea.id = a.id_estado_actividad
      AND a.estado = 1
      AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
      AND UPPER(TRIM(ea.nombre)) IN ('PENDIENTE', 'PROGRAMADA')
      AND (
          (v_tipo_origen = 'PRESTAMO' AND a.id_prestamo = p_id_origen)
          OR (v_tipo_origen = 'ALQUILER' AND a.id_alquiler = p_id_origen)
      );
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN v_n;
END;
$function$;

-- ===== funciones\actividades\age_crear_recojo_origen.sql =====
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

-- ===== funciones\actividades\age_listar_vencidos_recojo.sql =====
-- Function: age_listar_vencidos_recojo
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql
--
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- el módulo Balones > Recojos (bal_recojo) se retiró; el único recojo vivo que
-- excluye un origen es la actividad RECOJO vigente.
-- Además deja de ser STABLE: hacía SET TIME ZONE, que Postgres rechaza en
-- funciones no volátiles ("SET is not allowed in a non-volatile function"), así
-- que el selector de vencidos del formulario de actividades fallaba siempre.
-- Y el total se calcula en la misma sentencia que la página: el CTE
-- "filtrado" no existía para el segundo SELECT.

DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer);

CREATE OR REPLACE FUNCTION age_listar_vencidos_recojo(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 30,
    p_offset integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id_prestamo, a.id_alquiler
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND ta.nombre = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
    ),
    base AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.fecha_retorno_pactada AS fecha_pactada,
            (CURRENT_DATE - p.fecha_retorno_pactada)::INTEGER AS dias_vencido,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pd.id_balon IS NOT NULL
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada < CURRENT_DATE
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'
          AND EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd
              WHERE pd.id_prestamo = p.id
                AND pd.estado = 1
                AND pd.fecha_devolucion IS NULL
                AND pd.id_balon IS NOT NULL
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_prestamo = p.id)

        UNION ALL

        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ),
            a.fecha_fin_pactada,
            (CURRENT_DATE - a.fecha_fin_pactada)::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = a.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND ad.id_balon IS NOT NULL
            ),
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                a.id_producto_regulador IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            )
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND a.fecha_fin_pactada IS NOT NULL
          AND a.fecha_fin_pactada < CURRENT_DATE
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
          AND (
              EXISTS (
                  SELECT 1
                  FROM bal_alquiler_detalle ad
                  WHERE ad.id_alquiler = a.id
                    AND ad.estado = 1
                    AND ad.fecha_devolucion IS NULL
                    AND ad.id_balon IS NOT NULL
              )
              OR (
                  a.id_producto_regulador IS NOT NULL
                  AND a.fecha_devolucion_regulador IS NULL
              )
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_alquiler = a.id)
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(COALESCE(nombre_cliente, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    -- Total y página en la MISMA sentencia: un CTE solo vive dentro de la
    -- sentencia que lo declara (el segundo SELECT fallaba con
    -- «relation "filtrado" does not exist»).
    SELECT
        (SELECT COUNT(*) FROM filtrado),
        (
            SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC, t.numero), '[]'::JSON)
            FROM (
                SELECT *
                FROM filtrado
                ORDER BY dias_vencido DESC, numero
                LIMIT GREATEST(COALESCE(p_limite, 30), 1)
                OFFSET GREATEST(COALESCE(p_offset, 0), 0)
            ) t
        )
    INTO v_total, v_rows;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;

-- ===== funciones\alquileres\bal_devolver_regulador_alquiler.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_regulador_alquiler
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- se retira p_id_recojo (bal_recojo y bal_mantenimiento.id_recojo ya no existen).
DROP FUNCTION IF EXISTS bal_devolver_regulador_alquiler(p_id_alquiler integer, p_fecha date, p_condicion character varying, p_observacion character varying, p_id_recojo integer, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS bal_devolver_regulador_alquiler(p_id_alquiler integer, p_fecha date, p_condicion character varying, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_devolver_regulador_alquiler(p_id_alquiler integer, p_fecha date DEFAULT CURRENT_DATE, p_condicion character varying DEFAULT 'BUENO'::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_producto INTEGER;
    v_almacen INTEGER;
    v_numero VARCHAR;
    v_condicion VARCHAR := UPPER(TRIM(COALESCE(p_condicion, '')));
    v_id_condicion INTEGER;
    v_id_tipo_rep INTEGER;
    v_id_estado_pend INTEGER;
    v_id_mant INTEGER;
    v_mov JSON;
    v_obs VARCHAR(500);
    v_ya_devuelto DATE;
    v_stock_ok BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'El alquiler es obligatorio', 'registro', NULL);
    END IF;

    IF v_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
        RETURN json_build_object(
            'error', 'La condición del regulador debe ser BUENO o PARA_REPARAR',
            'registro', NULL
        );
    END IF;

    SELECT
        COALESCE(a.id_producto_stock, a.id_producto_regulador),
        a.id_almacen,
        a.numero_alquiler,
        a.fecha_devolucion_regulador,
        COALESCE(a.stock_regulador_reingresado, FALSE)
    INTO v_producto, v_almacen, v_numero, v_ya_devuelto, v_stock_ok
    FROM bal_alquiler a
    WHERE a.id = p_id_alquiler AND a.estado = 1;

    IF v_producto IS NULL THEN
        RETURN json_build_object(
            'error', 'El alquiler no tiene regulador/accesorio asociado',
            'registro', NULL
        );
    END IF;

    IF v_ya_devuelto IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object(
                'id_alquiler', p_id_alquiler,
                'ya_devuelto', TRUE,
                'fecha_devolucion_regulador', v_ya_devuelto
            )
        );
    END IF;

    SELECT lo.id INTO v_id_condicion
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'CondicionRegulador' AND lo.nombre = v_condicion AND lo.estado = 1
    LIMIT 1;

    IF v_id_condicion IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró la condición ' || v_condicion || ' en CondicionRegulador',
            'registro', NULL
        );
    END IF;

    v_obs := NULLIF(TRIM(COALESCE(p_observacion, '')), '');

    UPDATE bal_alquiler
    SET
        fecha_devolucion_regulador = COALESCE(p_fecha, CURRENT_DATE),
        id_condicion_regulador = v_id_condicion,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_alquiler AND estado = 1;

    IF v_condicion = 'BUENO' THEN
        IF NOT v_stock_ok
           AND v_almacen IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM pro_producto
               WHERE id = v_producto
                 AND estado = 1
                 AND COALESCE(afecta_stock, FALSE) = TRUE
           )
        THEN
            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => COALESCE(p_fecha, CURRENT_DATE),
                p_id_producto               => v_producto,
                p_cantidad                  => 1,
                p_id_almacen_origen         => v_almacen,
                p_codigo_tipo_documento_origen => 'ALQUILER',
                p_id_documento_origen       => p_id_alquiler,
                p_glosa                     => 'Reingreso regulador OK — alquiler ' || COALESCE(v_numero, '#' || p_id_alquiler),
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            -- Ya se marcó fecha_devolucion_regulador: fallar con RAISE para
            -- no dejar "devuelto" sin reingreso de stock.
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;

            UPDATE bal_alquiler
            SET
                stock_regulador_reingresado = TRUE,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = p_id_alquiler AND estado = 1;
        END IF;
    ELSE
        -- PARA_REPARAR: crear mantenimiento de producto (sin reingresar a stock aún)
        SELECT lo.id INTO v_id_tipo_rep
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMantenimiento' AND lo.nombre = 'REPARACION' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_pend
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pend IS NULL THEN
            RAISE EXCEPTION 'No se encontró el estado PENDIENTE de mantenimiento';
        END IF;

        INSERT INTO bal_mantenimiento (
            id_balon,
            id_producto,
            id_almacen,
            id_alquiler,
            id_tipo_mantenimiento,
            fecha_ingreso,
            descripcion,
            costo,
            es_externo,
            id_estado,
            observacion,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            NULL,
            v_producto,
            v_almacen,
            p_id_alquiler,
            v_id_tipo_rep,
            COALESCE(p_fecha, CURRENT_DATE),
            'Reparación de regulador/accesorio devuelto del alquiler '
                || COALESCE(v_numero, '#' || p_id_alquiler),
            0,
            FALSE,
            v_id_estado_pend,
            v_obs,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_mant;

        UPDATE bal_alquiler
        SET
            id_mantenimiento_regulador = v_id_mant,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_alquiler AND estado = 1;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id_alquiler', p_id_alquiler,
            'condicion', v_condicion,
            'id_mantenimiento', v_id_mant,
            'stock_reingresado', v_condicion = 'BUENO'
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte fecha_devolucion_regulador / stock parcial y expone al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;

-- ===== funciones\actividades\age_culminar_recojo.sql =====
-- Function: age_culminar_recojo
-- Cierra el recojo como REALIZADA tras verificar lo recogido y elige almacén
-- destino. Devuelve cada cilindro (préstamo/alquiler) al almacén indicado.

DROP FUNCTION IF EXISTS age_culminar_recojo(integer, integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_recojo(
    p_id integer,
    p_id_almacen_destino integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_nombre_tipo    VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_pendientes     INTEGER;
    v_item           RECORD;
    v_dev            JSON;
    v_devueltos      INTEGER := 0;
    v_esperados      INTEGER := 0;
    v_id_almacen_alq INTEGER;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_estado_actividad, a.id_prestamo, a.id_alquiler, a.id_cliente,
           a.id_trabajador_responsable, a.id_usuario_responsable
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM gen_lista_opciones lo WHERE lo.id = v_act.id_estado_actividad;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_tipo
    FROM age_actividad a JOIN gen_lista_opciones lo ON lo.id = a.id_tipo_actividad
    WHERE a.id = p_id;

    IF COALESCE(v_nombre_tipo, '') <> 'RECOJO' THEN
        RETURN json_build_object('error', 'Solo las actividades de RECOJO tienen este flujo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar un recojo que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF v_act.id_trabajador_responsable IS NULL AND v_act.id_usuario_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de culminar el recojo',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para culminar el recojo',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede culminar este recojo',
            'registro', NULL
        );
    END IF;

    IF p_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debes indicar el almacen destino donde ingresan los cilindros',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacen destino no existe o esta inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_realizada IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado REALIZADA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    -- En recojo el momento de verificación operativa es LLEGADA (= recogido
    -- confirmado). Las observaciones leves no bloquean.
    SELECT COUNT(*) FILTER (
        WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
          AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado
    )
    INTO v_pendientes
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s item(s) por verificar en el recojo antes de culminar',
                v_pendientes
            ),
            'registro', NULL
        );
    END IF;

    SELECT COUNT(*) INTO v_esperados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1
      AND (
            ai.id_prestamo_detalle IS NOT NULL
         OR ai.id_alquiler_detalle IS NOT NULL
         OR (ai.id_balon IS NULL AND ai.id_producto IS NOT NULL AND v_act.id_alquiler IS NOT NULL)
      );

    -- Devuelve cada cilindro al almacén elegido.
    -- Cualquier error de bal_devolver_* aborta con RAISE para revertir
    -- devoluciones parciales ya aplicadas en esta misma transacción.
    FOR v_item IN
        SELECT ai.id, ai.id_balon, ai.id_prestamo_detalle, ai.id_alquiler_detalle,
               ai.id_producto, ai.observacion_llegada
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id AND ai.estado = 1
        ORDER BY ai.item
    LOOP
        IF v_item.id_prestamo_detalle IS NOT NULL THEN
            v_dev := bal_devolver_prestamo_detalle(
                p_id                       => v_item.id_prestamo_detalle,
                p_fecha_devolucion         => CURRENT_DATE,
                p_id_almacen_destino       => p_id_almacen_destino,
                p_id_usuario_auditoria     => p_id_usuario_auditoria,
                p_nombre_estado_contenido  => 'VACIO',
                p_observacion              => COALESCE(v_item.observacion_llegada, 'Devolucion por actividad de recojo')
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;

        ELSIF v_item.id_alquiler_detalle IS NOT NULL THEN
            v_dev := bal_devolver_alquiler_detalle(
                p_id                   => v_item.id_alquiler_detalle,
                p_fecha_devolucion     => CURRENT_DATE,
                p_id_almacen_destino   => p_id_almacen_destino,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;

        ELSIF v_item.id_balon IS NULL
              AND v_item.id_producto IS NOT NULL
              AND v_act.id_alquiler IS NOT NULL THEN
            -- Accesorio/regulador materializado sin balón.
            -- bal_devolver_regulador_alquiler NO acepta p_id_almacen_destino:
            -- reingresa stock con bal_alquiler.id_almacen. Si es NULL, falla
            -- en claro en lugar de marcar REALIZADA sin reingreso.
            SELECT a.id_almacen INTO v_id_almacen_alq
            FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler AND a.estado = 1;

            IF v_id_almacen_alq IS NULL THEN
                RAISE EXCEPTION
                    'El alquiler no tiene id_almacen para reingresar el regulador; bal_devolver_regulador_alquiler no acepta almacen destino (defina id_almacen en el alquiler)';
            END IF;

            v_dev := bal_devolver_regulador_alquiler(
                p_id_alquiler          => v_act.id_alquiler,
                p_fecha                => CURRENT_DATE,
                p_condicion            => 'BUENO',
                p_observacion          => COALESCE(v_item.observacion_llegada, 'Devolucion por actividad de recojo'),
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
            v_devueltos := v_devueltos + 1;
        END IF;
    END LOOP;

    IF v_esperados > 0 AND v_devueltos = 0 THEN
        RAISE EXCEPTION
            'No se devolvio ningun cilindro/accesorio pese a haber % item(s) por devolver; no se marca REALIZADA',
            v_esperados;
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        hora_fin_estimada = COALESCE(hora_fin_estimada, LOCALTIME),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte devoluciones parciales del loop y expone el error al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;

-- ===== funciones\comprobantes\ven_cerrar_custodia_comprobante.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_cerrar_custodia_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- bal_devolver_regulador_alquiler ya no recibe p_id_recojo.
DROP FUNCTION IF EXISTS ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_alquiler RECORD;
    v_alq_det RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    -- Préstamos: devolver cilindros pendientes y cerrar cabecera
    FOR v_prestamo IN
        SELECT id FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        FOR v_detalle IN
            SELECT id FROM bal_prestamo_detalle
            WHERE estado = 1 AND id_prestamo = v_prestamo.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_prestamo_detalle(
                v_detalle.id,
                CURRENT_DATE,
                NULL,
                p_id_usuario,
                'VACIO',
                'Devolución automática por anulación/NC del comprobante'
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

    -- Recargas mostrador: devolver el gas a pro_stock y soltar el balón (inv_movimiento)
    FOR v_recarga IN
        SELECT id, id_balon
        FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id_comprobante
    LOOP
        v_result := inv_revertir_por_documento('RECARGA', v_recarga.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);

        UPDATE bal_movimiento_recarga
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE id = v_recarga.id AND estado = 1;
    END LOOP;

    -- Alquileres: reingreso de regulador y cilindros de detalle
    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            'Devolución automática por anulación/NC del comprobante',
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

        FOR v_alq_det IN
            SELECT id FROM bal_alquiler_detalle
            WHERE estado = 1 AND id_alquiler = v_alquiler.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_alquiler_detalle(v_alq_det.id, CURRENT_DATE, NULL, p_id_usuario);
            PERFORM ven_raise_si_error(v_result);
        END LOOP;

        SELECT lo.id INTO v_id_estado_final
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, CURRENT_DATE),
            id_estado = COALESCE(v_id_estado_final, id_estado),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_alquiler.id AND estado = 1;
    END LOOP;

    -- GRE PENDIENTE que referencia este CPE
    FOR v_guia IN
        SELECT DISTINCT g.id
        FROM doc_salida g
        INNER JOIN doc_salida_referencia r ON r.id_doc_salida = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
    LOOP
        v_result := gre_eliminar_guia_remision(v_guia.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Mantenimiento no finalizado ligado al CPE
    FOR v_mant IN
        SELECT m.id, m.id_balon, em.nombre AS nombre_estado
        FROM bal_mantenimiento m
        LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
        WHERE m.estado = 1 AND m.id_comprobante_venta = p_id_comprobante
    LOOP
        IF UPPER(COALESCE(v_mant.nombre_estado, '')) = 'FINALIZADO' THEN
            CONTINUE;
        END IF;

        UPDATE bal_mantenimiento
        SET
            estado = 0,
            id_comprobante_venta = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_mant.id AND estado = 1;

        SELECT lo.id INTO v_id_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon b
        SET
            id_estado_balon = COALESCE(v_id_en_almacen, b.id_estado_balon),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.id = v_mant.id_balon
          AND b.estado = 1
          AND EXISTS (
              SELECT 1 FROM gen_lista_opciones eb
              WHERE eb.id = b.id_estado_balon
                AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
          );
    END LOOP;

    -- Garantía sin reembolsos: se da de baja el cobro documental (el efectivo iba en el CPE)
    UPDATE ven_garantia_movimiento gm
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE gm.estado = 1
      AND gm.id_comprobante = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1
          FROM ven_garantia_movimiento d
          INNER JOIN gen_lista_opciones td ON td.id = d.id_tipo_movimiento
          WHERE d.id_garantia = gm.id_garantia
            AND d.estado = 1
            AND UPPER(td.nombre) = 'DEVOLUCION'
      );

    UPDATE ven_garantia g
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE g.estado = 1
      AND COALESCE(g.monto_devuelto, 0) = 0
      AND NOT EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm
          WHERE gm.id_garantia = g.id AND gm.estado = 1
      )
      AND EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm0
          WHERE gm0.id_garantia = g.id AND gm0.id_comprobante = p_id_comprobante
      );
END;
$function$;

-- ===== funciones\prestamos\bal_prestamo_cerrar_si_completo.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_cerrar_si_completo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- al cerrar el préstamo (sin detalles pendientes) cancela la actividad de
-- RECOJO que siguiera PENDIENTE / PROGRAMADA para ese préstamo. Es el punto
-- común de devolución en mostrador, renovación POS y anulación de comprobante.
DROP FUNCTION IF EXISTS bal_prestamo_cerrar_si_completo(p_id_prestamo integer, p_fecha date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_prestamo_cerrar_si_completo(p_id_prestamo integer, p_fecha date DEFAULT CURRENT_DATE, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pendientes INTEGER;
    v_id_estado_cerrado INTEGER;
BEGIN
    IF p_id_prestamo IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = p_id_prestamo
      AND estado = 1
      AND fecha_devolucion IS NULL;

    IF COALESCE(v_pendientes, 0) > 0 THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_estado_cerrado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'CERRADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_prestamo
    SET
        fecha_retorno_real = COALESCE(fecha_retorno_real, COALESCE(p_fecha, CURRENT_DATE)),
        id_estado = COALESCE(v_id_estado_cerrado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_prestamo
      AND estado = 1;

    -- Sin cilindros pendientes no hay nada que recoger: la actividad de
    -- RECOJO pendiente se cancela. Una EN_RUTA no se toca (la cierra el chofer
    -- con age_culminar_recojo, que es quien suele llegar aquí).
    PERFORM age_cancelar_recojos_pendientes_origen(
        'PRESTAMO',
        p_id_prestamo,
        p_id_usuario_auditoria,
        'Cancelada: el préstamo quedó sin cilindros pendientes de recojo'
    );
END;
$function$;

-- ===== funciones\prestamos-detalle\bal_devolver_prestamo_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- al devolver, cancelaba recojos vivos del préstamo (bal_recojo).
--
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- bal_recojo ya no existe; la actividad de RECOJO pendiente se cancela desde
-- bal_prestamo_cerrar_si_completo cuando el préstamo queda sin pendientes.
DROP FUNCTION IF EXISTS bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer, p_nombre_estado_contenido character varying, p_observacion character varying);

CREATE OR REPLACE FUNCTION bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_nombre_estado_contenido character varying DEFAULT 'VACIO'::character varying, p_observacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_obs_actual VARCHAR(500);
    v_obs_nueva VARCHAR(500);
    v_retorno JSON;
    v_id_producto_gas INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.observacion,
        p.id_cliente,
        p.id_almacen
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_obs_actual,
        v_id_cliente,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1
    FOR UPDATE OF pd;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de préstamo no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    SELECT lo.id INTO v_id_estado_detalle_devuelto
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
    LIMIT 1;

    v_obs_nueva := NULLIF(TRIM(p_observacion), '');
    IF v_obs_nueva IS NOT NULL THEN
        IF NULLIF(TRIM(v_obs_actual), '') IS NULL THEN
            v_obs_actual := LEFT(v_obs_nueva, 500);
        ELSE
            v_obs_actual := LEFT(TRIM(v_obs_actual) || ' | ' || v_obs_nueva, 500);
        END IF;
    END IF;

    IF v_id_balon IS NOT NULL THEN
        SELECT b.id_producto_gas INTO v_id_producto_gas
        FROM bal_balon b
        WHERE b.id = v_id_balon AND b.estado = 1;

        v_retorno := bal_prestamo_aplicar_retorno_cilindro(
            v_id_balon,
            v_id_prestamo,
            v_id_cliente,
            v_id_almacen_destino,
            COALESCE(NULLIF(TRIM(p_nombre_estado_contenido), ''), 'VACIO'),
            COALESCE(v_obs_nueva, 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria,
            TRUE
        );

        IF v_retorno->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_retorno->>'error', 'registro', NULL);
        END IF;
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_estado = COALESCE(v_id_estado_detalle_devuelto, id_estado),
        id_producto = COALESCE(v_id_producto_gas, id_producto),
        observacion = COALESCE(v_obs_actual, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    -- Si con esta devolución el préstamo queda completo, cierra la cabecera y
    -- cancela la actividad de RECOJO que siguiera pendiente (ya no hay nada
    -- que recoger). Ver bal_prestamo_cerrar_si_completo.
    PERFORM bal_prestamo_cerrar_si_completo(
        v_id_prestamo,
        COALESCE(p_fecha_devolucion, CURRENT_DATE),
        p_id_usuario_auditoria
    );

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;

-- ===== funciones\alquileres-detalle\bal_devolver_alquiler_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- al devolver, cancelaba recojos vivos del alquiler (bal_recojo).
--
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- bal_recojo ya no existe; al finalizar el alquiler se cancela la actividad de
-- RECOJO que siguiera pendiente (age_cancelar_recojos_pendientes_origen).
DROP FUNCTION IF EXISTS bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_finalizado INTEGER;
    v_mov_result JSON;
    v_pendientes INTEGER;
    v_nombre_estado_balon VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_alquiler,
        ad.id_balon,
        ad.fecha_devolucion,
        al.id_cliente,
        al.id_almacen
    INTO
        v_id_alquiler,
        v_id_balon,
        v_fecha_devolucion,
        v_id_cliente,
        v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1
    FOR UPDATE OF ad;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de alquiler no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacén de destino de la devolución',
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

    SELECT UPPER(TRIM(eb.nombre))
    INTO v_nombre_estado_balon
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = v_id_balon AND b.estado = 1;

    IF v_nombre_estado_balon IS NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro del detalle no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    -- Solo forzar DISPONIBLE si el balón está en un estado esperado de alquiler.
    IF v_nombre_estado_balon NOT IN ('ALQUILADO', 'POR_RECOGER') THEN
        RETURN json_build_object(
            'error',
            format(
                'No se puede devolver: el cilindro está %s (se esperaba ALQUILADO o POR_RECOGER)',
                LOWER(REPLACE(v_nombre_estado_balon, '_', ' '))
            ),
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_alquiler_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    v_mov_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
        p_fecha                     => LOCALTIMESTAMP,
        p_id_balon                  => v_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_destino        => v_id_almacen_destino,
        p_id_cliente                => v_id_cliente,
        p_codigo_tipo_documento_origen => 'ALQUILER',
        p_id_documento_origen       => v_id_alquiler,
        p_glosa                     => 'Entrada por devolución de alquiler',
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- Custodia: vuelve a almacén. Contenido: se asume vacío (envase usado que regresa).
    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = v_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_id_balon
      AND estado = 1;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_alquiler_detalle
    WHERE id_alquiler = v_id_alquiler
      AND estado = 1
      AND fecha_devolucion IS NULL;

    -- No cerrar si aún falta devolver el regulador/accesorio
    IF v_pendientes = 0
       AND NOT EXISTS (
           SELECT 1
           FROM bal_alquiler a
           WHERE a.id = v_id_alquiler
             AND a.estado = 1
             AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
             AND a.fecha_devolucion_regulador IS NULL
       )
    THEN
        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, COALESCE(p_fecha_devolucion, CURRENT_DATE)),
            id_estado = COALESCE(v_id_estado_finalizado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_alquiler
          AND estado = 1;

        -- Alquiler finalizado: la actividad de RECOJO pendiente ya no aplica.
        -- Una EN_RUTA no se toca (la cierra el chofer con age_culminar_recojo).
        PERFORM age_cancelar_recojos_pendientes_origen(
            'ALQUILER',
            v_id_alquiler,
            p_id_usuario_auditoria,
            'Cancelada: el alquiler quedó sin cilindros ni accesorios pendientes de recojo'
        );
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte fecha_devolucion / movimiento parcial y expone al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;

-- ===== funciones\comprobantes\ven_aplicar_efectos_pos.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- el auto-recojo del préstamo POS se agenda como actividad RECOJO
-- (age_crear_recojo_origen); bal_recojo dejó de existir como flujo.
-- Actualizada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql:
-- la renovación recibe la fecha de retorno pactada (antes se perdía) y la
-- garantía queda ligada al detalle del cilindro que respalda.

-- Function: ven_aplicar_efectos_pos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
--
-- Actualizada por database_sql/migraciones/20260905_pos_garantia_cuenta_y_catalogos.sql:
-- la garantia (de prestamo y de alquiler) se crea con su cuenta bancaria y su
-- numero de operacion, que antes nunca llegaban a ven_crear_garantia.
DROP FUNCTION IF EXISTS ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_arr JSON;
    v_result JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_baja INTEGER;
    v_garantia JSON;
    v_periodo JSON;
    v_id_producto INTEGER;
    v_id_prestamo_detalle INTEGER;
    v_garantia_balon JSON;
    v_id_balon_garantia INTEGER;
    v_id_propietario_garantia INTEGER;
    v_vigencia_ph_garantia INTEGER;
    v_fecha_ultima_ph_garantia DATE;
    v_fecha_proxima_ph_garantia DATE;
    v_observacion_balon_garantia VARCHAR;
    v_mov_garantia JSON;
    v_id_estado_balon_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL OR p_efectos IS NULL OR p_efectos::TEXT IN ('null', '{}', '[]') THEN
        RETURN;
    END IF;

    SELECT id_cliente, serie, numero
    INTO v_id_cliente, v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_comprobante AND estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante no existe o está inactivo';
    END IF;

    -- Recargas mostrador
    v_arr := CASE WHEN json_typeof(p_efectos->'recargas') = 'array' THEN p_efectos->'recargas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_vincular_recarga_cliente_comprobante(
            p_id_comprobante,
            v_id_cliente,
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULLIF(v_item->>'capacidad', '')::NUMERIC,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'idBalonOrigen', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Préstamos de cilindro (+ garantía opcional)
    v_arr := CASE WHEN json_typeof(p_efectos->'prestamos') = 'array' THEN p_efectos->'prestamos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        IF NULLIF(v_item->>'idPrestamoRenovar', '') IS NOT NULL THEN
            -- Fase 4 (apunte 1.c.ix): renovación — cierra el préstamo indicado
            -- (canjeando el cilindro si hay uno disponible, o extendiéndolo con
            -- el mismo) y abre uno nuevo encadenado, ligado a ESTA venta. Por
            -- defecto reutiliza la garantía (dinero y/o cilindro) del préstamo
            -- anterior; si mantenerGarantiaPrestamo es false, el bloque de
            -- garantia/garantiaBalon más abajo registra una nueva.
            v_result := bal_renovar_prestamo(
                p_id_prestamo                => (v_item->>'idPrestamoRenovar')::INTEGER,
                p_id_balon_nuevo             => NULLIF(v_item->>'idBalon', '')::INTEGER,
                p_id_usuario                 => p_id_usuario,
                p_id_comprobante_venta_nuevo => p_id_comprobante,
                p_mantener_garantia          => COALESCE((v_item->>'mantenerGarantiaPrestamo')::BOOLEAN, TRUE),
                p_fecha_retorno_pactada      => NULLIF(v_item->>'fechaRetornoPactada', '')::DATE
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo renovar el préstamo';
            END IF;

            SELECT pd.id INTO v_id_prestamo_detalle
            FROM bal_prestamo_detalle pd
            WHERE pd.id_prestamo = v_id_prestamo
              AND pd.rol = 'ENTREGADO'
              AND pd.estado = 1
            ORDER BY pd.id DESC
            LIMIT 1;
        ELSE
            v_result := bal_crear_prestamo(
                NULLIF(v_item->>'idTipoPrestamo', '')::INTEGER,
                NULL,
                v_id_cliente,
                NULL,
                NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                NULLIF(v_item->>'fechaSalida', '')::DATE,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL,
                NULLIF(TRIM(COALESCE(v_item->>'titulo', '')), ''),
                NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
                NULLIF(v_item->>'idEstado', '')::INTEGER,
                p_id_comprobante,
                NULL,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo crear el préstamo POS';
            END IF;

            v_result := bal_crear_prestamo_detalle(
                v_id_prestamo,
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'idProducto', '')::INTEGER,
                NULL,
                NULLIF(COALESCE(v_item->>'fechaEntregado', v_item->>'fechaSalida'), '')::DATE,
                NULLIF(COALESCE(v_item->>'fechaPrestamo', v_item->>'fechaSalida'), '')::DATE,
                30,
                NULLIF(COALESCE(v_item->>'fechaVencimiento', v_item->>'fechaRetornoPactada'), '')::DATE,
                NULL, NULL, NULL, NULL, NULL,
                NULLIF(v_item->>'idEstadoDetalle', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_item->>'observacionDetalle', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo_detalle := (v_result->'registro'->>'id')::INTEGER;
        END IF;

        -- Auto-recojo: el préstamo ya tiene fecha de retorno pactada, por lo que se
        -- agenda la actividad de RECOJO sin pasar por la pantalla manual. Nace
        -- PENDIENTE, sin responsable y a las 08:00 (misma hora que el batch
        -- age_generar_recojos_por_vencer); los ítems se materializan al iniciar.
        -- El cilindro se queda PRESTADO_CLIENTE hasta que el chófer inicia la ruta.
        IF v_id_prestamo_detalle IS NOT NULL
           AND NULLIF(v_item->>'idBalon', '') IS NOT NULL
           AND NULLIF(v_item->>'fechaRetornoPactada', '') IS NOT NULL
        THEN
            v_result := age_crear_recojo_origen(
                'PRESTAMO',
                v_id_prestamo,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                TIME '08:00',
                NULL::INTEGER,
                'Recojo automático generado al vender el préstamo',
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                v_id_prestamo,
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                NULL,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), ''),
                v_id_prestamo_detalle
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        -- Fase 4 (apunte 1.c.viii) — préstamo con garantía de balón: el cliente deja
        -- su propio cilindro como colateral y se lleva uno de Sarita recargado.
        -- Distinto de v_garantia (dinero): aquí se registra un balón físico nuevo,
        -- de propietario CLIENTE (el envase sigue siendo suyo y se le devuelve),
        -- con su propia fila de detalle (rol GARANTIA) enlazada al mismo préstamo
        -- que ya tiene el detalle ENTREGADO creado arriba. Es esa fila —y no el
        -- propietario— la que dice que lo tenemos en garantía y de qué préstamo.
        v_garantia_balon := v_item->'garantiaBalon';
        IF json_typeof(v_garantia_balon) = 'object'
           AND NULLIF(v_garantia_balon->>'codigoBalon', '') IS NOT NULL
        THEN
            v_vigencia_ph_garantia := COALESCE(
                NULLIF(v_garantia_balon->>'vigenciaPruebaHidrostaticaAnios', '')::INTEGER, 5
            );
            v_fecha_ultima_ph_garantia := NULLIF(v_garantia_balon->>'fechaUltimaPruebaHidrostatica', '')::DATE;
            v_fecha_proxima_ph_garantia := CASE
                WHEN v_fecha_ultima_ph_garantia IS NOT NULL
                THEN (v_fecha_ultima_ph_garantia + (v_vigencia_ph_garantia || ' years')::INTERVAL)::DATE
                ELSE NULL
            END;

            v_observacion_balon_garantia := NULLIF(TRIM(COALESCE(v_garantia_balon->>'observacion', '')), '');
            IF v_fecha_proxima_ph_garantia IS NOT NULL AND v_fecha_proxima_ph_garantia < CURRENT_DATE THEN
                v_observacion_balon_garantia := TRIM(
                    COALESCE(v_observacion_balon_garantia || ' — ', '')
                    || 'Prueba hidrostática vencida al recibir en garantía ('
                    || TO_CHAR(v_fecha_proxima_ph_garantia, 'DD/MM/YYYY') || ')'
                );
            END IF;

            SELECT lo.id INTO v_id_propietario_garantia
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_propietario_garantia IS NULL THEN
                RAISE EXCEPTION 'Falta la opción CLIENTE en el catálogo PropietarioBalon';
            END IF;

            SELECT lo.id INTO v_id_estado_balon_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            v_result := bal_crear_balon(
                p_codigo_balon                          => TRIM(v_garantia_balon->>'codigoBalon'),
                p_fecha_registro                        => CURRENT_DATE,
                p_id_almacen                             => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_propietario                        => v_id_propietario_garantia,
                p_id_cliente_propietario                => v_id_cliente,
                p_id_tipo_balon                         => NULLIF(v_garantia_balon->>'idTipoBalon', '')::INTEGER,
                p_id_producto_gas                       => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_id_estado_balon                       => v_id_estado_balon_almacen,
                p_fecha_ultima_prueba_hidrostatica      => v_fecha_ultima_ph_garantia,
                p_vigencia_prueba_hidrostatica_anios    => v_vigencia_ph_garantia,
                p_fecha_proxima_prueba_hidrostatica     => v_fecha_proxima_ph_garantia,
                p_observacion                            => v_observacion_balon_garantia,
                p_numero_serie                          => NULLIF(v_garantia_balon->>'numeroSerie', ''),
                p_id_usuario_auditoria                  => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_balon_garantia := (v_result->'registro'->>'id')::INTEGER;

            IF v_id_balon_garantia IS NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el cilindro de garantía';
            END IF;

            v_mov_garantia := inv_registrar_movimiento(
                p_naturaleza                    => 'BALON',
                p_codigo_tipo_movimiento        => 'ENTRADA_GARANTIA',
                p_id_balon                      => v_id_balon_garantia,
                p_cantidad                      => 1,
                p_id_almacen_destino            => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_cliente                    => v_id_cliente,
                p_codigo_tipo_documento_origen  => 'PRESTAMO',
                p_id_documento_origen           => v_id_prestamo,
                p_glosa                         => 'Cilindro dejado en garantía por el cliente',
                p_id_usuario_auditoria          => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_mov_garantia);

            v_result := bal_crear_prestamo_detalle(
                p_id_prestamo            => v_id_prestamo,
                p_id_balon               => v_id_balon_garantia,
                p_id_producto            => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_observacion            => 'Cilindro recibido en garantía',
                p_id_usuario_auditoria   => p_id_usuario,
                p_rol                    => 'GARANTIA'
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- GRE solo si el usuario lo pidió (opt-in). Sin flag no se emite.
    IF COALESCE(
        NULLIF(p_efectos->>'generarGre', '')::BOOLEAN,
        NULLIF(p_efectos->>'generar_gre', '')::BOOLEAN,
        FALSE
    ) THEN
        PERFORM ven_pos_crear_guia_remision(p_id_comprobante, p_id_usuario);
    END IF;

    -- Alquiler de regulador/accesorio (+ periodo + garantía)
    v_arr := CASE WHEN json_typeof(p_efectos->'alquileres') = 'array' THEN p_efectos->'alquileres' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_alquiler(
            NULL,
            v_id_cliente,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(v_item->>'fechaInicio', '')::DATE,
            NULLIF(v_item->>'fechaFinPactada', '')::DATE,
            NULL,
            COALESCE(NULLIF(v_item->>'tarifaDiaria', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item->>'totalCobrado', '')::NUMERIC, 0),
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_comprobante,
            NULLIF(v_item->>'idProductoRegulador', '')::INTEGER,
            NULLIF(v_item->>'idProductoStock', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_alquiler := (v_result->'registro'->>'id')::INTEGER;
        IF v_id_alquiler IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el alquiler POS';
        END IF;

        v_periodo := v_item->'periodo';
        IF json_typeof(v_periodo) = 'object' THEN
            v_result := bal_registrar_alquiler_periodo(
                v_id_alquiler,
                NULLIF(v_periodo->>'fechaInicio', '')::DATE,
                NULLIF(v_periodo->>'fechaFin', '')::DATE,
                COALESCE(NULLIF(v_periodo->>'monto', '')::NUMERIC, 0),
                NULLIF(v_periodo->>'idProducto', '')::INTEGER,
                p_id_comprobante,
                NULLIF(TRIM(COALESCE(v_periodo->>'observacion', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_id_producto := COALESCE(
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULLIF(v_item->>'idProductoRegulador', '')::INTEGER
            );
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                NULL,
                v_id_producto,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                v_id_alquiler,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), '')
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- Mantenimientos
    v_arr := CASE WHEN json_typeof(p_efectos->'mantenimientos') = 'array' THEN p_efectos->'mantenimientos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_mantenimiento(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'fechaIngreso', '')::DATE,
            NULLIF(v_item->>'idTipoMantenimiento', '')::INTEGER,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
            COALESCE(NULLIF(v_item->>'costo', '')::NUMERIC, 0),
            FALSE,
            NULL,
            NULL,
            p_id_comprobante,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_usuario,
            NULL,
            NULL,
            NULL,
            NULL
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Baja por venta de cilindro
    v_arr := CASE WHEN json_typeof(p_efectos->'bajas') = 'array' THEN p_efectos->'bajas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_dar_baja_balon(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idMotivoBaja', '')::INTEGER,
            p_id_usuario,
            NULL,
            NULL,
            v_id_cliente,
            p_id_comprobante,
            v_serie,
            v_numero,
            NULLIF(v_item->>'montoVenta', '')::NUMERIC,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'fechaBaja', '')::DATE,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_baja := (v_result->'registro'->>'id')::INTEGER;

        IF COALESCE((v_item->>'aprobar')::BOOLEAN, FALSE) AND v_id_baja IS NOT NULL THEN
            v_result := bal_aprobar_baja_balon(
                v_id_baja,
                p_id_usuario,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;
END;
$function$;

-- ===== funciones\documentos-salida\doc_anular_salida.sql =====
-- Function: doc_anular_salida
--
-- Anula el ciclo de la OS y libera custodia logística (PENDIENTE_ENVIO /
-- EN_TRANSITO → DISPONIBLE). Si hay reparto vigente, hay que cancelarlo antes.
-- También se invoca en cascada desde ven_eliminar_comprobante (path con
-- id_venta): ese camino no pasa por inv_revertir_por_documento, así que la
-- liberación de balones vive aquí.
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
-- una orden de planta con compra activa vinculada no se anula (anular la
-- compra primero). Con ello la reversa por ORDEN_SALIDA cubre ida + retorno
-- completos (envases y gas declarado en la orden).
--
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el id del estado ANULADA se resuelve antes de revertir inventario.
--
-- Actualizada por database_sql/migraciones/20260910_venta_custodia_mostrador_anular.sql:
-- un REPARTO ya REALIZADA bloquea la anulación. La entrega ocurrió: los
-- cilindros están EN_PODER_CLIENTE y liberarlos a DISPONIBLE inventaría
-- envases que no tenemos. La corrección documental es una nota de crédito.
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- bloqueaba si había bal_recojo PROGRAMADO/EN_RUTA con id_doc_salida = p_id.
--
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- se retira ese bloqueo: bal_recojo y el recojo de planta ya no existen; el
-- retorno de planta se registra solo con bal_finalizar_recarga_planta.
DROP FUNCTION IF EXISTS doc_anular_salida(p_id integer, p_motivo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_anular_salida(p_id integer, p_motivo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_compra RECORD;
    v_id_anulada INTEGER;
    v_rev JSON;
    v_id_disponible INTEGER;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o ya fue eliminado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El documento fue aceptado por SUNAT; requiere comunicación de baja, no anulación directa',
            'registro', NULL
        );
    END IF;

    -- Ticket PSE pendiente: anular rompería el correlativo/ticket en SUNAT
    -- sin poder reconciliar (consultarEstado rechaza ANULADA).
    IF NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'La guía tiene un ticket SUNAT pendiente; consulta el CDR o espera la aceptación antes de anular',
            'registro', NULL
        );
    END IF;

    -- Orden de planta con factura vinculada: la compra tiene su gas del retorno
    -- etiquetado COMPRA, que la reversa por ORDEN_SALIDA no alcanza. Anular la
    -- compra primero (que desvincula y ajusta el gas) deja todo consistente.
    IF v_doc.id_comprobante_compra IS NOT NULL AND EXISTS (
        SELECT 1 FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra AND c.estado = 1
    ) THEN
        SELECT c.serie, c.numero INTO v_compra
        FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra;

        RETURN json_build_object(
            'error', format(
                'La orden tiene la compra %s vinculada; anúlala primero en Compras',
                COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), ''), '#' || v_doc.id_comprobante_compra)
            ),
            'registro', NULL
        );
    END IF;

    -- Entrega ya realizada: los cilindros pasaron a EN_PODER_CLIENTE y el
    -- cliente se quedó con ellos. Anular repondría stock inexistente, así que
    -- se bloquea aquí y también en la cascada desde ven_eliminar_comprobante.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'El reparto de esta orden ya fue entregado al cliente; no se puede anular. '
            || 'Registra la devolución de los cilindros o emite una nota de crédito.',
            'registro', NULL
        );
    END IF;

    -- No anular si hay reparto / actividad operativa todavía vigente.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN (
              'CANCELADA', 'CANCELADO', 'REALIZADA'
          )
    ) THEN
        RETURN json_build_object(
            'error', 'Hay actividad de reparto vigente; cancélala antes de anular la OS',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_disponible
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_disponible IS NULL OR v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados DISPONIBLE, PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    -- El estado ANULADA se resuelve antes de revertir inventario: si faltara en
    -- el catálogo, el error soft se devolvía con los movimientos ya revertidos y
    -- la orden seguía activa.
    SELECT lo.id INTO v_id_anulada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'ANULADA' AND lo.estado = 1;

    IF v_id_anulada IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado ANULADA en catalogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    -- Solo se revierte lo que este documento movió por su cuenta.
    IF v_doc.id_venta IS NULL THEN
        v_rev := inv_revertir_por_documento('ORDEN_SALIDA', p_id, p_id_usuario_auditoria);

        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;

        UPDATE doc_salida_detalle
        SET id_movimiento = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_doc_salida = p_id;
    END IF;

    -- ------------------------------------------------------------
    -- Custodia logística: PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE
    --
    -- Con id_venta el inventario lo movió la venta (no hay movimiento OS),
    -- pero los cilindros sí quedaron comprometidos al crear la OS
    -- (doc_crear_desde_venta). Sin esto quedan atrapados al anular.
    -- Sin id_venta, cubre residuales que no hayan pasado por kardex BALON.
    -- ------------------------------------------------------------
    UPDATE bal_balon b
    SET id_estado_balon = v_id_disponible,
        id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE b.estado = 1
      AND b.id_estado_balon IN (v_id_pend_envio, v_id_transito)
      AND b.id IN (
          SELECT dd.id_balon
          FROM doc_salida_detalle dd
          WHERE dd.id_doc_salida = p_id
            AND dd.id_balon IS NOT NULL
            AND dd.estado = 1
          UNION
          SELECT vd.id_balon
          FROM ven_comprobante_detalle vd
          WHERE v_doc.id_venta IS NOT NULL
            AND vd.id_comprobante = v_doc.id_venta
            AND vd.id_balon IS NOT NULL
            AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
          UNION
          -- Misma cobertura que doc_crear_desde_venta / doc_obtener_salida
          SELECT pd.id_balon
          FROM bal_prestamo pr
          INNER JOIN bal_prestamo_detalle pd
              ON pd.id_prestamo = pr.id AND pd.estado = 1
          WHERE v_doc.id_venta IS NOT NULL
            AND pr.id_comprobante_venta = v_doc.id_venta
            AND pr.estado = 1
            AND pd.rol = 'ENTREGADO'
            AND pd.id_balon IS NOT NULL
      );

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_anulada,
        observaciones = TRIM(BOTH ' ' FROM CONCAT_WS(' | ',
            NULLIF(observaciones, ''),
            'Anulada: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'))),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;

-- ===== funciones\recargas-planta\bal_finalizar_recarga_planta.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
-- Actualizada por database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql:
--   el retorno se registra en dos planos, igual que la salida. La línea del
--   balón mueve SOLO el envase (antes ingresaba 1 unidad de gas por cilindro,
--   sin entrada consolidada). El gas ingresa consolidado por producto con la
--   cantidad de la factura de compra vinculada (o, sin factura, con las líneas
--   de gas del propio documento). Además, un guard impide registrar dos veces
--   el retorno de la misma orden.
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · el retorno exige la orden GENERADA / EMITIDA_SUNAT (en borrador no hay
--     salida que retornar);
--   · los envases se etiquetan SIEMPRE ORDEN_SALIDA + id orden: el retorno
--     físico es un hecho de la orden, no de la factura. Así anular la compra ya
--     no deshace la custodia de los cilindros;
--   · el gas lo registra bal_sincronizar_gas_retorno_planta (factura vinculada
--     o, sin factura, líneas de gas de la orden), la misma función que
--     re-sincroniza cuando la factura llega o cambia después.
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   · fecha_llegada_almacen / fecha_retorno solo se escriben cuando los
--     cilindros de verdad volvieron. Con p_guardar_balones_almacen = false y
--     sin ENTRADA_PLANTA_EXTERNA previa la llamada es metadata (factura, guía,
--     lote, ficha ICP) y NO declara el retorno. Antes bastaba con mandar la
--     fecha para que todo aguas abajo (listados, CompraForm, com_crear_compra)
--     diera el retorno por hecho: los cilindros quedaban EN_RECARGA_EXTERNA,
--     sin gas ingresado, y la compra ya no volvía a finalizarlo;
--   · el retorno ya no pisa doc_salida.id_almacen (el almacén de origen de la
--     salida se perdía): el almacén de llegada va a id_almacen_retorno;
--   · la fecha de P.H. del retorno baja al libro de P.H. de cada cilindro
--     (bal_sync_ph_desde_orden_salida);
--   · la ficha ICP (p_id_lote_protocolo) se aplica a los cilindros de la orden
--     aunque esta llamada no sea la que registra el retorno físico — antes solo
--     se aplicaba si el mismo llamado recorría el bucle de envases, así que por
--     el camino de Compras nunca llegaba a los balones.
-- Actualizada por database_sql/migraciones/20260911_w1_planta_retorno_traslado_gas.sql:
--   los cilindros de una orden de planta pueden volver por dos caminos — este
--   retorno y el recojo (bal_registrar_resultado_recojo) — y cada uno usa su
--   propio tipo de movimiento, así que el guard de doble retorno existente
--   (ENTRADA_PLANTA_EXTERNA) no veía al otro. Ahora el retorno se rechaza si hay
--   un recojo vivo (PROGRAMADO / EN_RUTA) sobre la orden o si el recojo ya
--   ingresó los cilindros (ENTRADA_LLENADO vigente).
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
--   el recojo de planta (bal_recojo) se retiró; queda solo el guard sobre
--   ENTRADA_LLENADO histórica para órdenes que cerraron por ese camino.
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_usuario_auditoria integer);

-- p_lote / p_fecha_vencimiento_lote / p_fecha_prueba_hidrostatica: antes los
-- llenaba bal_actualizar_recarga_planta (eliminada en la unificación a
-- doc_salida). Es el mismo paso del flujo — registrar el retorno — así que
-- se agregan aquí en vez de crear otra función.
-- p_id_lote_protocolo (Fase 5): ficha ICP con la que volvieron los cilindros.
-- Va al final de la firma para no romper las llamadas posicionales existentes.
CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer DEFAULT NULL::integer, p_guardar_balones_almacen boolean DEFAULT false, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_lote_protocolo integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_orden RECORD;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_retorno_fisico BOOLEAN;
    v_retorno_por_recojo BOOLEAN;
    v_det RECORD;
    v_mov JSON;
    v_gas JSON;
    v_id_balones INTEGER[];
    v_id_lote_aplicar INTEGER;
    v_aplic JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id, d.id_comprobante_compra, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_orden
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id_recarga_planta AND d.estado = 1
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
        RETURN json_build_object(
            'error', 'El documento no es una orden de recarga en planta externa',
            'registro', NULL
        );
    END IF;

    -- Sin salida generada no hay cilindros en planta que puedan volver: en
    -- borrador el inventario nunca se movió y el retorno dejaría envases
    -- "de vuelta" de un viaje que no existió.
    IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        RETURN json_build_object(
            'error', CASE
                WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden está anulada'
                ELSE 'La orden aún está en borrador: genérala antes de registrar el retorno'
            END,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_entrada_planta
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_entrada_planta IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado',
            'registro', NULL
        );
    END IF;

    -- Único criterio de "los cilindros volvieron": la entrada vigente de algún
    -- envase de la orden. Mismo criterio que bal_sincronizar_gas_retorno_planta
    -- y com_crear_compra, para que los tres coincidan siempre. Al anular la
    -- orden (inv_revertir_por_documento) los movimientos quedan con estado = 0
    -- y el retorno vuelve a estar pendiente.
    SELECT EXISTS (
        SELECT 1
        FROM inv_movimiento m
        JOIN doc_salida_detalle d ON d.id = m.id_documento_detalle
        WHERE m.estado = 1
          AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
          AND m.naturaleza = 'BALON'
          AND d.id_doc_salida = p_id_recarga_planta
          AND d.id_balon IS NOT NULL
          AND m.id_balon = d.id_balon
    ) INTO v_retorno_fisico;

    IF p_guardar_balones_almacen THEN
        -- Guard de doble retorno: va antes del UPDATE de cabecera para que un
        -- reenvío no deje la orden con fecha/almacén distintos a los de los
        -- movimientos ya hechos.
        IF v_retorno_fisico THEN
            RETURN json_build_object(
                'error', 'El retorno de esta orden ya fue registrado; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        -- Órdenes cerradas por el antiguo recojo de planta (retirado): sus
        -- cilindros entraron con ENTRADA_LLENADO, que el guard de arriba
        -- (ENTRADA_PLANTA_EXTERNA) no ve. Sin esto, el retorno los ingresaría
        -- de nuevo con una segunda entrada de gas.
        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
            JOIN gen_lista_opciones td ON td.id = m.id_tipo_documento_origen
            JOIN doc_salida_detalle d
                ON d.id_doc_salida = p_id_recarga_planta
               AND d.estado = 1
               AND d.id_balon = m.id_balon
            WHERE m.estado = 1
              AND m.naturaleza = 'BALON'
              AND UPPER(TRIM(tm.nombre)) = 'ENTRADA_LLENADO'
              AND UPPER(TRIM(td.nombre)) = 'RECARGA'
              AND m.id_documento_origen = p_id_recarga_planta
        ) INTO v_retorno_por_recojo;

        IF v_retorno_por_recojo THEN
            RETURN json_build_object(
                'error', 'Los cilindros de esta orden ya volvieron por el recojo; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        IF p_id_almacen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'Indica el almacén al que llegan los cilindros',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Datos del retorno sobre el propio documento. Las fechas de llegada solo se
    -- escriben si los cilindros vuelven en esta llamada (p_guardar_balones_almacen)
    -- o si ya habían vuelto antes: sin entrada física, declarar la fecha dejaba
    -- la orden como retornada y bloqueaba el retorno de verdad.
    -- id_almacen queda como el origen de la salida; el almacén de llegada va a
    -- id_almacen_retorno.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen)
            ELSE fecha_llegada_almacen
        END,
        fecha_retorno = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_retorno)
            ELSE fecha_retorno
        END,
        id_almacen_retorno = CASE
            WHEN p_guardar_balones_almacen THEN COALESCE(p_id_almacen, id_almacen_retorno)
            ELSE id_almacen_retorno
        END,
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_lote_protocolo = COALESCE(p_id_lote_protocolo, id_lote_protocolo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_recarga_planta;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        -- ------------------------------------------------------------
        -- 1) Envases: una línea por cilindro. Mueve SOLO el envase (custodia
        --    DISPONIBLE + LLENO en el almacén de llegada), igual que la línea
        --    del balón en la salida. Se etiqueta ORDEN_SALIDA + id orden
        --    (como la ida): el retorno físico no depende de la factura, así
        --    que anular la compra no lo deshace; anular la orden
        --    (doc_anular_salida) revierte ida y vuelta juntas.
        -- ------------------------------------------------------------
        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon
            FROM doc_salida_detalle d
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
            ORDER BY d.item
        LOOP
            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'BALON',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => NULL,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => 1,
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id_recarga_planta,
                p_glosa                        => format(
                    'Entrada por recarga en planta externa (orden #%s)', p_id_recarga_planta
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada del balón %: %',
                    v_det.id_balon, v_mov->>'error';
            END IF;
        END LOOP;

        v_retorno_fisico := TRUE;

        -- ------------------------------------------------------------
        -- 2) Gas: consolidado por producto con la cantidad que realmente
        --    ingresa (factura vinculada o, si no hay, líneas de gas de la
        --    orden). Es la misma función que vuelve a correr cuando la
        --    factura llega o cambia después del retorno.
        -- ------------------------------------------------------------
        v_gas := bal_sincronizar_gas_retorno_planta(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    -- Fase 5: ficha ICP vigente en los cilindros. Usa el parámetro o la ficha
    -- ya enganchada en la orden (Registrar lote desde la OS).
    v_id_lote_aplicar := COALESCE(
        p_id_lote_protocolo,
        (SELECT d.id_lote_protocolo FROM doc_salida d WHERE d.id = p_id_recarga_planta)
    );

    IF v_id_lote_aplicar IS NOT NULL THEN
        SELECT array_agg(d.id_balon ORDER BY d.item)
        INTO v_id_balones
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL;

        IF array_length(v_id_balones, 1) IS NOT NULL THEN
            v_aplic := bal_aplicar_lote_protocolo_balones(
                v_id_lote_aplicar,
                array_to_json(v_id_balones),
                p_id_usuario_auditoria,
                p_id_recarga_planta
            );
            IF v_aplic->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_aplic->>'error';
            END IF;
        ELSIF p_id_lote_protocolo IS NOT NULL THEN
            -- Solo metadata: engancha la ficha a la orden aunque aún no haya
            -- cilindros en el detalle (caso raro; el UPDATE de cabecera ya
            -- escribió id_lote_protocolo vía COALESCE).
            UPDATE doc_salida
            SET id_lote_protocolo = p_id_lote_protocolo
            WHERE id = p_id_recarga_planta AND estado = 1
              AND id_lote_protocolo IS DISTINCT FROM p_id_lote_protocolo;
        END IF;
    END IF;

    -- La P.H. del retorno es una prueba real hecha en planta: baja al libro de
    -- P.H. de cada cilindro que volvió. Sin retorno físico no hay qué anotar.
    IF v_retorno_fisico THEN
        PERFORM bal_sync_ph_desde_orden_salida(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta,
        'retorno_fisico', v_retorno_fisico,
        'gas', v_gas->'registro'
    ));
END;
$function$;

-- ===== funciones\mantenimientos\bal_listar_mantenimientos.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_mantenimientos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- sin columna id_recojo (bal_recojo eliminada).
DROP FUNCTION IF EXISTS bal_listar_mantenimientos(p_busqueda character varying, p_limite integer, p_offset integer, p_id_balon integer, p_id_tipo_mantenimiento integer, p_id_estado integer, p_es_externo boolean);

CREATE OR REPLACE FUNCTION bal_listar_mantenimientos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_balon integer DEFAULT NULL::integer, p_id_tipo_mantenimiento integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_es_externo boolean DEFAULT NULL::boolean)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_mantenimiento m
    LEFT JOIN bal_balon b ON m.id_balon = b.id
    LEFT JOIN pro_producto p ON p.id = m.id_producto
    WHERE m.estado = 1
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_tipo_mantenimiento IS NULL OR m.id_tipo_mantenimiento = p_id_tipo_mantenimiento)
      AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
      AND (p_es_externo IS NULL OR m.es_externo = p_es_externo)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(m.descripcion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            CASE
                WHEN m.id_producto IS NOT NULL THEN 'PRODUCTO'
                ELSE 'CILINDRO'
            END AS tipo_origen,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(
                    TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)),
                    ''
                ),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            b.id_cliente_ubicacion,
            m.id_tipo_mantenimiento,
            tm.nombre AS nombre_tipo_mantenimiento,
            m.fecha_ingreso,
            m.fecha_salida,
            m.descripcion,
            m.costo,
            m.es_externo,
            m.id_estado,
            em.nombre AS nombre_estado,
            m.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            m.id_comprobante_compra,
            CASE
                WHEN cc.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cc.serie, cc.numero)
            END AS comprobante_compra,
            m.id_alquiler,
            m.estado,
            m.fecha_creacion,
            (
                m.id_comprobante_venta IS NULL
                AND m.id_comprobante_compra IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_balon_ph_historial ph
                    WHERE ph.id_mantenimiento = m.id AND ph.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_mantenimiento m
        LEFT JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
        LEFT JOIN gen_lista_opciones em ON m.id_estado = em.id
        LEFT JOIN ven_comprobante cv ON m.id_comprobante_venta = cv.id
        LEFT JOIN com_comprobante_compra cc ON m.id_comprobante_compra = cc.id
        WHERE m.estado = 1
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_tipo_mantenimiento IS NULL OR m.id_tipo_mantenimiento = p_id_tipo_mantenimiento)
          AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
          AND (p_es_externo IS NULL OR m.es_externo = p_es_externo)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(m.descripcion, ''), p_busqueda)
          )
        ORDER BY m.fecha_ingreso DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- ===== funciones\mantenimientos\bal_obtener_mantenimiento.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.948Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- sin columna id_recojo (bal_recojo eliminada).
DROP FUNCTION IF EXISTS bal_obtener_mantenimiento(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_mantenimiento(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            CASE
                WHEN m.id_producto IS NOT NULL THEN 'PRODUCTO'
                ELSE 'CILINDRO'
            END AS tipo_origen,
            m.id_almacen,
            m.id_alquiler,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            cp.razon_social AS nombre_cliente_propietario,
            b.id_cliente_ubicacion,
            m.id_tipo_mantenimiento,
            tm.nombre AS nombre_tipo_mantenimiento,
            m.fecha_ingreso,
            m.fecha_salida,
            m.descripcion,
            m.costo,
            m.es_externo,
            m.id_proveedor,
            prov.razon_social AS nombre_proveedor,
            m.id_estado,
            em.nombre AS nombre_estado,
            m.id_comprobante_venta,
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            cv_cli.razon_social AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            m.id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            cc.fecha AS fecha_comprobante_compra,
            cc_prov.razon_social AS nombre_proveedor_comprobante_compra,
            cc.total_importe AS total_comprobante_compra,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_mantenimiento m
        LEFT JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
        LEFT JOIN cli_clientes prov ON m.id_proveedor = prov.id
        LEFT JOIN gen_lista_opciones em ON m.id_estado = em.id
        LEFT JOIN ven_comprobante cv ON m.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN com_comprobante_compra cc ON m.id_comprobante_compra = cc.id
        LEFT JOIN cli_clientes cc_prov ON cc.id_proveedor = cc_prov.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


-- ============================================================
-- DATOS: bal_recojo vivos → actividad RECOJO pendiente
-- ============================================================
DO $mig$
DECLARE
    v_r      RECORD;
    v_res    JSON;
    v_trab   INTEGER;
    v_ok     INTEGER := 0;
    v_skip   INTEGER := 0;
BEGIN
    IF to_regclass('public.bal_recojo') IS NULL THEN
        RAISE NOTICE 'bal_recojo ya no existe: nada que migrar';
        RETURN;
    END IF;

    FOR v_r IN
        SELECT r.id, r.id_prestamo, r.id_alquiler, r.fecha_programada,
               r.hora_estimada, r.id_usuario_responsable, r.observacion
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
          AND (r.id_prestamo IS NOT NULL OR r.id_alquiler IS NOT NULL)
        ORDER BY r.id
    LOOP
        v_trab := NULL;
        IF v_r.id_usuario_responsable IS NOT NULL THEN
            SELECT u.id_trabajador INTO v_trab
            FROM auth_usuarios u WHERE u.id = v_r.id_usuario_responsable;
        END IF;

        v_res := age_crear_recojo_origen(
            CASE WHEN v_r.id_prestamo IS NOT NULL THEN 'PRESTAMO' ELSE 'ALQUILER' END,
            COALESCE(v_r.id_prestamo, v_r.id_alquiler),
            v_r.fecha_programada,
            COALESCE(v_r.hora_estimada, TIME '08:00'),
            v_trab,
            LEFT(COALESCE(NULLIF(TRIM(v_r.observacion), ''), 'Recojo')
                 || format(' (migrado de Balones > Recojos #%s)', v_r.id), 500),
            NULL
        );

        IF v_res->>'error' IS NOT NULL THEN
            v_skip := v_skip + 1;
            RAISE NOTICE 'bal_recojo #% no migrado: %', v_r.id, v_res->>'error';
        ELSE
            v_ok := v_ok + 1;
        END IF;
    END LOOP;

    RAISE NOTICE 'bal_recojo migrados a actividades: % (omitidos: %)', v_ok, v_skip;
END
$mig$;

-- ============================================================
-- DROP funciones del módulo de recojos (todas las sobrecargas)
-- ============================================================
DO $mig$
DECLARE
    v_f RECORD;
BEGIN
    FOR v_f IN
        SELECT p.oid::regprocedure AS firma
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'bal_actualizar_recojo',
              'bal_crear_recojo',
              'bal_eliminar_recojo',
              'bal_generar_recojo_recarga_planta',
              'bal_listar_pendientes_recojo',
              'bal_listar_recojos',
              'bal_obtener_recojo',
              'bal_registrar_resultado_recojo',
              'bal_validar_codigos_recojo'
          )
    LOOP
        EXECUTE format('DROP FUNCTION %s', v_f.firma);
    END LOOP;
END
$mig$;

-- ============================================================
-- DROP tablas y columna
-- ============================================================
ALTER TABLE bal_mantenimiento DROP COLUMN IF EXISTS id_recojo;
DROP TABLE IF EXISTS bal_recojo_detalle;
DROP TABLE IF EXISTS bal_recojo;

-- ============================================================
-- Catálogos exclusivos del módulo retirado
-- ============================================================
DELETE FROM gen_lista_opciones lo
USING gen_lista l
WHERE l.id = lo.id_lista
  AND l.nombre IN ('EstadoRecojo', 'ResultadoRecojoDetalle', 'MotivoFalloRecojo');

DELETE FROM gen_lista
WHERE nombre IN ('EstadoRecojo', 'ResultadoRecojoDetalle', 'MotivoFalloRecojo');

-- ============================================================
-- Permisos recojos_balon.*
-- ============================================================
DELETE FROM auth_roles_permisos rp
USING auth_permisos p
WHERE p.id = rp.id_permiso
  AND p.nombre LIKE 'recojos_balon.%';

DELETE FROM auth_permisos
WHERE nombre LIKE 'recojos_balon.%';
