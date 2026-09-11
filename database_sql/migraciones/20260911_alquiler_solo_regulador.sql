-- ============================================================
-- Migración: el alquiler es solo del regulador/accesorio — retiro de bal_alquiler_detalle
-- Fecha: 2026-09-11
--
-- Regla de negocio: el cilindro NUNCA se alquila; si se entrega es un
-- préstamo (bal_prestamo). El alquiler (bal_alquiler) cubre solo el regulador
-- o accesorio (id_producto_regulador / id_producto_stock). Existía todavía el
-- modelo anterior con cilindros en bal_alquiler_detalle, un módulo API
-- (alquileres-detalle), pantallas "(legado)" y ramas en el recojo de
-- actividades. Desde esta migración ese camino desaparece.
--
-- Qué cambia
--  1) bal_devolver_regulador_alquiler: al devolver el accesorio el alquiler
--     queda FINALIZADO y se cancela la actividad de RECOJO pendiente. Es la
--     única devolución del alquiler (nuevo endpoint
--     POST /balones/alquileres/:id/devolver-regulador).
--  2) Actividades: age_iniciar_verificacion materializa para ALQUILER un solo
--     ítem (el accesorio, sin balón); age_culminar_recojo lo reingresa con
--     bal_devolver_regulador_alquiler; age_listar_vencidos_recojo y
--     age_obtener_actividad ya no miran cilindros del alquiler.
--  3) bal_reporte_alquileres_antiguedad: reescrita por alquiler (accesorio
--     pendiente, días fuera y días de atraso). Pierde p_excluir_bajas.
--  4) bal_listar_alquileres / bal_obtener_alquiler: sin total_detalles;
--     exponen fecha_devolucion_regulador, condición y mantenimiento.
--  5) Sin chequeos de bal_alquiler_detalle en bal_eliminar_alquiler,
--     bal_eliminar_balon, bal_listar_balones, bal_crear/actualizar_prestamo_detalle,
--     bal_eliminar_mantenimiento, cli_listar_clientes_mapa,
--     ven_cerrar_custodia_comprobante.
--  6) DROP de las 6 funciones bal_*_alquiler_detalle*, de dash_balones_alquilados
--     (KPI sin consumidor), de la tabla bal_alquiler_detalle, de la columna
--     age_actividad_item.id_alquiler_detalle y de los permisos alquileres_detalle.*.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_alquiler_solo_regulador.sql
-- ============================================================


-- ===== funciones\alquileres\bal_devolver_regulador_alquiler.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_regulador_alquiler
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- se retira p_id_recojo (bal_recojo y bal_mantenimiento.id_recojo ya no existen).
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- al devolver el regulador el alquiler queda FINALIZADO y se cancela la
-- actividad de RECOJO pendiente (antes lo hacía bal_devolver_alquiler_detalle,
-- eliminada junto con bal_alquiler_detalle).
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
    v_id_estado_finalizado INTEGER;
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

    -- El alquiler es solo del regulador/accesorio: devuelto este, el contrato
    -- queda FINALIZADO y la actividad de RECOJO que siguiera pendiente ya no
    -- aplica (una EN_RUTA la cierra el chofer con age_culminar_recojo).
    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_alquiler
    SET
        fecha_fin_real = COALESCE(fecha_fin_real, COALESCE(p_fecha, CURRENT_DATE)),
        id_estado = COALESCE(v_id_estado_finalizado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_alquiler AND estado = 1;

    PERFORM age_cancelar_recojos_pendientes_origen(
        'ALQUILER',
        p_id_alquiler,
        p_id_usuario_auditoria,
        'Cancelada: el regulador/accesorio del alquiler ya fue devuelto'
    );

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

-- ===== funciones\alquileres\bal_eliminar_alquiler.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_alquiler
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin chequeo de bal_alquiler_detalle (tabla eliminada; el alquiler es solo regulador).
DROP FUNCTION IF EXISTS bal_eliminar_alquiler(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_alquiler(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_comprobante_venta
    INTO v_id_comprobante_venta
    FROM bal_alquiler
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el alquiler porque tiene un comprobante vinculado'
        );
    END IF;

    UPDATE bal_alquiler
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

-- ===== funciones\alquileres\bal_listar_alquileres.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_alquileres
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin total_detalles (bal_alquiler_detalle eliminada); puede_eliminar depende solo del
-- comprobante; expone fecha_devolucion_regulador / condición / mantenimiento del accesorio.
DROP FUNCTION IF EXISTS bal_listar_alquileres(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_id_almacen integer, p_id_estado integer);

CREATE OR REPLACE FUNCTION bal_listar_alquileres(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_alquiler al
    LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
    LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
    WHERE al.estado = 1
      AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
      AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
      AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
          OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            al.id_producto_regulador,
            pr.codigo AS codigo_producto_regulador,
            pr.nombre AS nombre_producto_regulador,
            al.id_producto_stock,
            ps.codigo AS codigo_producto_stock,
            ps.nombre AS nombre_producto_stock,
            al.fecha_devolucion_regulador,
            al.id_condicion_regulador,
            cr.nombre AS nombre_condicion_regulador,
            al.id_mantenimiento_regulador,
            al.estado,
            al.fecha_creacion,
            (al.id_comprobante_venta IS NULL) AS puede_eliminar
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN gen_lista_opciones cr ON al.id_condicion_regulador = cr.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
        WHERE al.estado = 1
          AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
          AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
              OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
          )
        ORDER BY al.fecha_inicio DESC, al.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- ===== funciones\alquileres\bal_obtener_alquiler.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_alquiler
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin total_detalles (bal_alquiler_detalle eliminada); expone fecha_devolucion_regulador /
-- condición / mantenimiento del accesorio.
DROP FUNCTION IF EXISTS bal_obtener_alquiler(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_alquiler(p_id integer)
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
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.observacion,
            al.id_comprobante_venta,
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            cv_cli.razon_social AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            al.id_producto_regulador,
            pr.codigo AS codigo_producto_regulador,
            pr.nombre AS nombre_producto_regulador,
            al.id_producto_stock,
            ps.codigo AS codigo_producto_stock,
            ps.nombre AS nombre_producto_stock,
            al.fecha_devolucion_regulador,
            al.id_condicion_regulador,
            cr.nombre AS nombre_condicion_regulador,
            al.id_mantenimiento_regulador,
            al.dias_periodo,
            al.estado,
            al.fecha_creacion,
            al.fecha_modificacion,
            al.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            al.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN gen_lista_opciones cr ON al.id_condicion_regulador = cr.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
        LEFT JOIN auth_usuarios uc ON al.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON al.id_usuario_modificacion = um.id
        WHERE al.id = p_id AND al.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ===== funciones\alquileres\bal_reporte_alquileres_antiguedad.sql =====
-- Function: bal_reporte_alquileres_antiguedad
-- Reescrita por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler es solo del regulador/accesorio (el cilindro va por préstamo y
-- bal_alquiler_detalle se eliminó). El reporte es una fila por alquiler con
-- accesorio pendiente de devolución; los días se cuentan desde fecha_inicio
-- y el atraso desde fecha_fin_pactada.
--
-- Firma: se retira p_excluir_bajas (era un filtro sobre el estado del cilindro).

DROP FUNCTION IF EXISTS bal_reporte_alquileres_antiguedad(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_rango_dias character varying, p_excluir_bajas boolean, p_solo_pendientes boolean);
DROP FUNCTION IF EXISTS bal_reporte_alquileres_antiguedad(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_rango_dias character varying, p_solo_pendientes boolean);

CREATE OR REPLACE FUNCTION bal_reporte_alquileres_antiguedad(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 50,
    p_offset integer DEFAULT 0,
    p_id_cliente integer DEFAULT NULL::integer,
    p_rango_dias character varying DEFAULT NULL::character varying,
    p_solo_pendientes boolean DEFAULT true
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH base AS (
        SELECT
            a.id AS id_alquiler,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            a.id_almacen,
            alm.nombre AS nombre_almacen,
            COALESCE(a.id_producto_regulador, a.id_producto_stock) AS id_producto,
            COALESCE(pr.nombre, ps.nombre) AS nombre_producto,
            COALESCE(pr.codigo, ps.codigo) AS codigo_producto,
            ea.nombre AS nombre_estado,
            a.dias_periodo,
            a.tarifa_diaria,
            a.fecha_inicio AS fecha_inicio_alquiler,
            a.fecha_fin_pactada,
            a.fecha_devolucion_regulador AS fecha_devolucion,
            cr.nombre AS nombre_condicion_regulador,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                ELSE (CURRENT_DATE - a.fecha_inicio)::INTEGER
            END AS dias_en_alquiler,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                WHEN a.fecha_fin_pactada IS NULL THEN NULL
                ELSE GREATEST((CURRENT_DATE - a.fecha_fin_pactada)::INTEGER, 0)
            END AS dias_atraso,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN 'DEVUELTO'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 180 THEN 'CRITICO_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 90 THEN 'SEGUIMIENTO_90_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 30 THEN 'ATENCION_30_90'
                ELSE 'RECIENTE_0_30'
            END AS rango_antiguedad
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_almacen alm ON alm.id = a.id_almacen
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        LEFT JOIN gen_lista_opciones cr ON cr.id = a.id_condicion_regulador
        WHERE a.estado = 1
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
          AND a.fecha_inicio IS NOT NULL
          AND (p_solo_pendientes = FALSE OR a.fecha_devolucion_regulador IS NULL)
          AND (p_id_cliente IS NULL OR a.id_cliente = p_id_cliente)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(a.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ps.codigo, ''), p_busqueda)
          )
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE (
            p_rango_dias IS NULL
            OR p_rango_dias = ''
            OR rango_antiguedad = p_rango_dias
        )
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM filtrado
                    ORDER BY
                        CASE WHEN dias_en_alquiler IS NULL THEN 1 ELSE 0 END,
                        dias_atraso DESC NULLS LAST,
                        dias_en_alquiler DESC NULLS LAST,
                        nombre_cliente ASC NULLS LAST,
                        numero_alquiler ASC NULLS LAST
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total_pendientes', COUNT(*) FILTER (WHERE rango_antiguedad <> 'DEVUELTO'),
                    'reciente_0_30', COUNT(*) FILTER (WHERE rango_antiguedad = 'RECIENTE_0_30'),
                    'atencion_30_90', COUNT(*) FILTER (WHERE rango_antiguedad = 'ATENCION_30_90'),
                    'seguimiento_90_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'SEGUIMIENTO_90_180'),
                    'critico_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'CRITICO_180')
                )
                FROM base
            ) AS resumen
    )
    SELECT ag.total, ag.registros, ag.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado ag;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total_pendientes', 0,
                'reciente_0_30', 0,
                'atencion_30_90', 0,
                'seguimiento_90_180', 0,
                'critico_180', 0
            )
        )
    );
END;
$function$;

-- ===== funciones\actividades\age_iniciar_verificacion.sql =====
-- Function: age_iniciar_verificacion
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- origen ALQUILER materializa solo el regulador/accesorio (bal_alquiler_detalle
-- eliminada; el cilindro siempre es préstamo).

DROP FUNCTION IF EXISTS age_iniciar_verificacion(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_verificacion(
    p_id_actividad integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act RECORD;
    v_id_pendiente INTEGER;
    v_items INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_prestamo, a.id_alquiler, a.id_doc_salida, a.id_comprobante,
           a.id_trabajador_responsable
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item i
        WHERE i.id_actividad = p_id_actividad AND i.estado = 1
    ) THEN
        RETURN age_obtener_actividad(p_id_actividad);
    END IF;

    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de iniciar la verificacion',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NOT NULL THEN
        DECLARE
            v_id_trabajador_sesion INTEGER;
        BEGIN
            SELECT u.id_trabajador INTO v_id_trabajador_sesion
            FROM auth_usuarios u
            WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

            IF v_id_trabajador_sesion IS NULL
               OR v_id_trabajador_sesion IS DISTINCT FROM v_act.id_trabajador_responsable THEN
                RETURN json_build_object(
                    'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar la verificacion',
                    'registro', NULL
                );
            END IF;
        END;
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_act.id_prestamo IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
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
        WHERE pd.id_prestamo = v_act.id_prestamo
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_alquiler IS NOT NULL THEN
        -- El alquiler es solo del regulador/accesorio (el cilindro va por
        -- préstamo): un único ítem sin balón, con el producto alquilado.
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            1,
            COALESCE(a.id_producto_regulador, a.id_producto_stock),
            COALESCE(pr.nombre, ps.nombre, 'Regulador / accesorio'),
            1,
            NULL,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_act.id_alquiler
          AND a.estado = 1
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
          AND a.fecha_devolucion_regulador IS NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_doc_salida IS NOT NULL OR v_act.id_comprobante IS NOT NULL THEN
        -- REPARTO sin items materializados: no hay nada que derivar aqui, los
        -- items los crea age_crear_actividad desde el detalle del documento.
        RETURN json_build_object(
            'error', 'La actividad de reparto no tiene items: revisa el documento de origen',
            'registro', NULL
        );
    ELSE
        RETURN json_build_object(
            'error', 'La actividad no tiene origen del que derivar items',
            'registro', NULL
        );
    END IF;

    RETURN age_obtener_actividad(p_id_actividad);
END;
$function$;

-- ===== funciones\actividades\age_culminar_recojo.sql =====
-- Function: age_culminar_recojo
-- Cierra el recojo como REALIZADA tras verificar lo recogido y elige almacén
-- destino. Devuelve cada cilindro del préstamo al almacén indicado y, en un
-- recojo de alquiler, reingresa el regulador/accesorio.
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler ya no tiene detalle de cilindros (bal_alquiler_detalle eliminada);
-- el ítem de alquiler es siempre el regulador (sin balón).

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
         OR (ai.id_balon IS NULL AND ai.id_producto IS NOT NULL AND v_act.id_alquiler IS NOT NULL)
      );

    -- Devuelve cada cilindro al almacén elegido.
    -- Cualquier error de bal_devolver_* aborta con RAISE para revertir
    -- devoluciones parciales ya aplicadas en esta misma transacción.
    FOR v_item IN
        SELECT ai.id, ai.id_balon, ai.id_prestamo_detalle,
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

        ELSIF v_item.id_balon IS NULL
              AND v_item.id_producto IS NOT NULL
              AND v_act.id_alquiler IS NOT NULL THEN
            -- Regulador/accesorio del alquiler (ítem sin balón).
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
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler vencido entra solo por el regulador/accesorio pendiente
-- (bal_alquiler_detalle eliminada).

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
            -- El alquiler no lleva cilindros (van por préstamo).
            0::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
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
          -- Solo hay algo que recoger si el regulador/accesorio sigue fuera.
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
          AND a.fecha_devolucion_regulador IS NULL
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

-- ===== funciones\actividades\age_obtener_actividad.sql =====
-- Function: age_obtener_actividad
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- el alquiler ya no tiene detalle de cilindros (bal_alquiler_detalle eliminada);
-- el origen ALQUILER expone solo el regulador/accesorio pendiente.

CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id integer)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_detalle_origen JSON := NULL;
    v_tiene_items BOOLEAN;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            um.nombre AS nombre_unidad_medida,
            i.id_balon,
            b.codigo_balon,
            b.numero_serie AS numero_serie_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            COALESCE(pgb.nombre, p.nombre) AS nombre_producto_gas,
            i.id_estado_verificacion_salida,
            evs.nombre AS estado_verificacion_salida,
            i.observacion_salida,
            i.id_estado_verificacion_llegada,
            evl.nombre AS estado_verificacion_llegada,
            i.observacion_llegada,
            i.id_estado_producto_recogido,
            epr.nombre AS estado_producto_recogido,
            i.id_doc_salida_detalle,
            i.id_venta_detalle,
            i.id_prestamo_detalle
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones evs ON evs.id = i.id_estado_verificacion_salida
        LEFT JOIN gen_lista_opciones evl ON evl.id = i.id_estado_verificacion_llegada
        LEFT JOIN gen_lista_opciones epr ON epr.id = i.id_estado_producto_recogido
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    v_tiene_items := COALESCE(json_array_length(v_items), 0) > 0;

    SELECT act.id_prestamo, act.id_alquiler
    INTO v_id_prestamo, v_id_alquiler
    FROM age_actividad act
    WHERE act.id = p_id AND act.estado = 1;

    IF NOT v_tiene_items AND v_id_prestamo IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'PRESTAMO',
            'id_origen', p.id,
            'numero', p.numero_prestamo,
            'fecha_pactada', p.fecha_retorno_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        pd.id,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        COALESCE(pd.id_producto, b.id_producto_gas) AS id_producto,
                        COALESCE(pg.nombre, pgb.nombre) AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pg ON pg.id = pd.id_producto
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE pd.id_prestamo = p.id
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                      AND pd.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_prestamo = p.id AND vg.estado = 1
                ) g
            ), '[]'::JSON)
        )
        INTO v_detalle_origen
        FROM bal_prestamo p
        WHERE p.id = v_id_prestamo;
    ELSIF NOT v_tiene_items AND v_id_alquiler IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'ALQUILER',
            'id_origen', a.id,
            'numero', a.numero_alquiler,
            'fecha_pactada', a.fecha_fin_pactada,
            -- El alquiler es solo del regulador/accesorio; el cilindro va por
            -- préstamo. Se mantiene la clave para el frontend, siempre vacía.
            'cilindros', '[]'::JSON,
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_alquiler = a.id AND vg.estado = 1
                ) g
            ), '[]'::JSON),
            'regulador', CASE
                WHEN COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL AND a.fecha_devolucion_regulador IS NULL
                THEN json_build_object(
                    'id_producto', COALESCE(a.id_producto_regulador, a.id_producto_stock),
                    'nombre_producto', COALESCE(pr.nombre, ps.nombre),
                    'codigo_producto', COALESCE(pr.codigo, ps.codigo),
                    'pendiente', TRUE
                )
                ELSE NULL
            END
        )
        INTO v_detalle_origen
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_id_alquiler;
    END IF;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_prestamo,
            bp.numero_prestamo,
            bp.fecha_retorno_pactada AS fecha_retorno_pactada_prestamo,
            act.id_alquiler,
            ba.numero_alquiler,
            ba.fecha_fin_pactada AS fecha_fin_pactada_alquiler,
            act.id_tipo_origen,
            tor.nombre AS nombre_tipo_origen,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items,
            v_detalle_origen AS detalle_origen
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN gen_lista_opciones tor ON tor.id = act.id_tipo_origen
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN bal_prestamo bp ON bp.id = act.id_prestamo
        LEFT JOIN bal_alquiler ba ON ba.id = act.id_alquiler
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON act.id_usuario_modificacion = umod.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ===== funciones\comprobantes\ven_cerrar_custodia_comprobante.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_cerrar_custodia_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- bal_devolver_regulador_alquiler ya no recibe p_id_recojo.
--
-- Actualizada por database_sql/migraciones/20260911_gre_anular_por_doc_salida.sql:
-- la GRE pendiente que referencia el CPE se anula con doc_anular_salida.
-- Antes llamaba a gre_eliminar_guia_remision (modelo gre_guia_remision,
-- anterior a doc_salida) que ya no existe en la BD: anular o emitir NC total
-- de un comprobante con guía pendiente fallaba con "function does not exist".
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin loop de bal_alquiler_detalle (tabla eliminada; el alquiler es solo regulador).
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

    -- Alquileres: reingreso del regulador/accesorio (el alquiler no lleva
    -- cilindros; esos van por préstamo). bal_devolver_regulador_alquiler ya
    -- finaliza el contrato; el UPDATE de abajo cubre un alquiler sin accesorio.
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

    -- GRE (doc_salida) no aceptada por SUNAT que referencia este CPE.
    -- Las guías viven en doc_salida desde F2; se anulan con doc_anular_salida,
    -- que revierte la salida de inventario y libera la custodia de los
    -- cilindros (PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE). Es idempotente
    -- sobre una ya ANULADA (p. ej. la OS de la venta que ven_eliminar_comprobante
    -- anuló antes por id_venta) y falla en claro si la guía tiene ticket SUNAT
    -- pendiente o un reparto vigente: ese error sí debe frenar la anulación.
    FOR v_guia IN
        SELECT DISTINCT g.id, c.serie, c.numero
        FROM doc_salida g
        INNER JOIN doc_salida_referencia r ON r.id_doc_salida = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        INNER JOIN gen_lista_opciones ec ON ec.id = g.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND ec.nombre <> 'ANULADA'
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
          AND NOT COALESCE(g.emitido_sunat, FALSE)
    LOOP
        v_result := doc_anular_salida(
            v_guia.id,
            format(
                'Comprobante %s-%s anulado / con nota de crédito',
                COALESCE(v_guia.serie, ''),
                COALESCE(v_guia.numero, p_id_comprobante::TEXT)
            ),
            p_id_usuario
        );
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

-- ===== funciones\balones\bal_eliminar_balon.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_balon
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin chequeo de bal_alquiler_detalle (el cilindro nunca se alquila).
DROP FUNCTION IF EXISTS bal_eliminar_balon(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_balon(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT eb.nombre
    INTO v_estado_nombre
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.id = p_id AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Conservar historial: baja aprobada / robado no se descarta del libro
    IF v_estado_nombre IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar un cilindro dado de baja o robado. El historial se conserva para negociaciones con plantas.'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id AND estado = 1 AND estado_aprobacion = 'APROBADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar un cilindro con baja aprobada. Use el filtro «Dados de baja» para consultarlo.'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id AND estado = 1 AND estado_aprobacion = 'PENDIENTE'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar: hay una solicitud de baja pendiente. Apruebe o rechace la baja.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM inv_movimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene movimientos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_movimiento_recarga WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene recargas. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está en préstamos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_mantenimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene mantenimientos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_balon_ph_historial WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene historial de P.H. Solicite baja para conservarlo.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_balon_estado_historial WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene historial de baja/reactivación. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está referenciado en comprobantes de venta.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM doc_salida_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está referenciado en guías de remisión.'
        );
    END IF;

    UPDATE bal_balon
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

-- ===== funciones\balones\bal_listar_balones.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_balones
-- Overloads: 3
-- Generated: 2026-09-03T16:50:38.946Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin chequeo de bal_alquiler_detalle en puede_eliminar (el cilindro nunca se alquila).
DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer, p_id_cliente_relacionado integer, p_solo_bajas boolean, p_familia_gas character varying, p_id_propietario integer, p_id_producto_gas integer, p_solo_llenos_fuera boolean, p_id_planta integer, p_tipo_valvula character varying);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer, p_id_cliente_relacionado integer DEFAULT NULL::integer, p_solo_bajas boolean DEFAULT NULL::boolean, p_familia_gas character varying DEFAULT NULL::character varying, p_id_propietario integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_solo_llenos_fuera boolean DEFAULT NULL::boolean, p_id_planta integer DEFAULT NULL::integer, p_tipo_valvula character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_alertas JSON;
    v_resumen JSON;
    v_familia_gas VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_familia_gas := NULLIF(TRIM(COALESCE(p_familia_gas, '')), '');

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'en_almacen', COUNT(*) FILTER (WHERE eb.nombre = 'DISPONIBLE')
        )
    INTO v_total, v_resumen
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
    LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_producto_gas IS NULL OR b.id_producto_gas = p_id_producto_gas)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
      AND (p_id_propietario IS NULL OR b.id_propietario = p_id_propietario)
      AND (
          p_id_cliente_relacionado IS NULL
          OR b.id_cliente_ubicacion = p_id_cliente_relacionado
          OR b.id_cliente_propietario = p_id_cliente_relacionado
      )
      AND (
          p_id_cliente_relacionado IS NULL
          OR eb.nombre IS NULL
          OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
      )
      AND (
          p_solo_bajas IS NULL
          OR (
              p_solo_bajas = TRUE
              AND eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
          )
          OR (
              p_solo_bajas = FALSE
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
          )
      )
      AND (
          p_solo_llenos_fuera IS NOT TRUE
          OR (
              COALESCE(eb.nombre, '') IS DISTINCT FROM 'DISPONIBLE'
              AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
      )
      AND (
          p_ph_vencida IS NULL
          OR (
              p_ph_vencida = TRUE
              AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
          )
          OR (
              p_ph_vencida = FALSE
              AND (
                  b.fecha_proxima_prueba_hidrostatica IS NULL
                  OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              )
          )
      )
      AND (
          p_ph_por_vencer_dias IS NULL
          OR (
              b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
          )
      )
      AND (
          v_familia_gas IS NULL
          OR gen_texto_coincide(COALESCE(tb.nombre, ''), v_familia_gas)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_familia_gas)
          OR gen_texto_coincide(COALESCE(pg.codigo, ''), v_familia_gas)
      )
      AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
      AND (
          p_tipo_valvula IS NULL
          OR b.tipo_valvula ILIKE '%' || TRIM(p_tipo_valvula) || '%'
      )
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(b.libro_cilindro, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tb.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(mc.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.numero_documento, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            COALESCE(
                NULLIF(TRIM(cu.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cu.nombres, cu.apellido_paterno, cu.apellido_materno)), ''),
                cu.numero_documento
            ) AS nombre_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            tb.capacidad_lb,
            tb.peso AS peso_tipo_balon,
            b.peso_aproximado_kg,
            COALESCE(b.peso_aproximado_kg, tb.peso) AS peso_guia_kg,
            b.sello_inspeccion,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_planta,
            COALESCE(pl.razon_social, TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno))) AS nombre_planta,
            b.anio_fabricacion,
            b.mes_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            b.tipo_valvula,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'APROBADA'
            ) AS tiene_baja_aprobada,
            NOT (
                COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
                OR EXISTS (
                    SELECT 1 FROM bal_baja_balon bb
                    WHERE bb.id_balon = b.id AND bb.estado = 1
                      AND bb.estado_aprobacion IN ('PENDIENTE', 'APROBADA')
                )
                OR EXISTS (SELECT 1 FROM inv_movimiento m WHERE m.id_balon = b.id AND m.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_movimiento_recarga mr WHERE mr.id_balon = b.id AND mr.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_prestamo_detalle pd WHERE pd.id_balon = b.id AND pd.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_mantenimiento mt WHERE mt.id_balon = b.id AND mt.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_ph_historial ph WHERE ph.id_balon = b.id AND ph.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_estado_historial eh WHERE eh.id_balon = b.id AND eh.estado = 1)
                OR EXISTS (SELECT 1 FROM ven_comprobante_detalle vd WHERE vd.id_balon = b.id AND vd.estado = 1)
                OR EXISTS (SELECT 1 FROM doc_salida_detalle gd WHERE gd.id_balon = b.id AND gd.estado = 1)
            ) AS puede_eliminar,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN cli_clientes pl ON b.id_planta = pl.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_producto_gas IS NULL OR b.id_producto_gas = p_id_producto_gas)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
          AND (p_id_propietario IS NULL OR b.id_propietario = p_id_propietario)
          AND (
              p_id_cliente_relacionado IS NULL
              OR b.id_cliente_ubicacion = p_id_cliente_relacionado
              OR b.id_cliente_propietario = p_id_cliente_relacionado
          )
          AND (
              p_id_cliente_relacionado IS NULL
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (
              p_solo_bajas IS NULL
              OR (
                  p_solo_bajas = TRUE
                  AND eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
              )
              OR (
                  p_solo_bajas = FALSE
                  AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
              )
          )
          AND (
              p_solo_llenos_fuera IS NOT TRUE
              OR (
                  COALESCE(eb.nombre, '') IS DISTINCT FROM 'DISPONIBLE'
                  AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
              )
          )
          AND (
              p_ph_vencida IS NULL
              OR (
                  p_ph_vencida = TRUE
                  AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              )
              OR (
                  p_ph_vencida = FALSE
                  AND (
                      b.fecha_proxima_prueba_hidrostatica IS NULL
                      OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  )
              )
          )
          AND (
              p_ph_por_vencer_dias IS NULL
              OR (
                  b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
              )
          )
          AND (
              v_familia_gas IS NULL
              OR gen_texto_coincide(COALESCE(tb.nombre, ''), v_familia_gas)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_familia_gas)
              OR gen_texto_coincide(COALESCE(pg.codigo, ''), v_familia_gas)
          )
          AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
          AND (
              p_tipo_valvula IS NULL
              OR b.tipo_valvula ILIKE '%' || TRIM(p_tipo_valvula) || '%'
          )
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.libro_cilindro, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tb.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mc.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.numero_documento, ''), p_busqueda)
          )
        ORDER BY b.fecha_creacion DESC NULLS LAST, b.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    SELECT json_build_object(
        'ph_por_vencer_90', COUNT(*) FILTER (
            WHERE b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days'
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
        ),
        'ph_vencida', COUNT(*) FILTER (
            WHERE b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
        ),
        'dados_de_baja', COUNT(*) FILTER (
            WHERE eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
        )
    )
    INTO v_alertas
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.estado = 1;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'alertas', v_alertas,
        'resumen', v_resumen
    );
END;
$function$;

DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer, p_id_cliente_relacionado integer);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer, p_id_cliente_relacionado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
      AND (
          p_id_cliente_relacionado IS NULL
          OR b.id_cliente_ubicacion = p_id_cliente_relacionado
          OR b.id_cliente_propietario = p_id_cliente_relacionado
      )
      AND (
          p_id_cliente_relacionado IS NULL
          OR eb.nombre IS NULL
          OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
      )
      AND (
          p_ph_vencida IS NULL
          OR (
              p_ph_vencida = TRUE
              AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
          )
          OR (
              p_ph_vencida = FALSE
              AND (
                  b.fecha_proxima_prueba_hidrostatica IS NULL
                  OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              )
          )
      )
      AND (
          p_ph_por_vencer_dias IS NULL
          OR (
              b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
          )
      )
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.anio_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
          AND (
              p_id_cliente_relacionado IS NULL
              OR b.id_cliente_ubicacion = p_id_cliente_relacionado
              OR b.id_cliente_propietario = p_id_cliente_relacionado
          )
          AND (
              p_id_cliente_relacionado IS NULL
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (
              p_ph_vencida IS NULL
              OR (
                  p_ph_vencida = TRUE
                  AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              )
              OR (
                  p_ph_vencida = FALSE
                  AND (
                      b.fecha_proxima_prueba_hidrostatica IS NULL
                      OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  )
              )
          )
          AND (
              p_ph_por_vencer_dias IS NULL
              OR (
                  b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
              )
          )
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY b.codigo_balon ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
      AND (
          p_ph_vencida IS NULL
          OR (
              p_ph_vencida = TRUE
              AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
          )
          OR (
              p_ph_vencida = FALSE
              AND (
                  b.fecha_proxima_prueba_hidrostatica IS NULL
                  OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              )
          )
      )
      AND (
          p_ph_por_vencer_dias IS NULL
          OR (
              b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
          )
      )
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.anio_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
          AND (
              p_ph_vencida IS NULL
              OR (
                  p_ph_vencida = TRUE
                  AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              )
              OR (
                  p_ph_vencida = FALSE
                  AND (
                      b.fecha_proxima_prueba_hidrostatica IS NULL
                      OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  )
              )
          )
          AND (
              p_ph_por_vencer_dias IS NULL
              OR (
                  b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
              )
          )
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY b.codigo_balon ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- ===== funciones\prestamos-detalle\bal_crear_prestamo_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
--
-- Fase 4 (apunte 1.c.viii) — agrega p_rol ('ENTREGADO' | 'GARANTIA') para que un
-- mismo préstamo pueda tener tanto el cilindro entregado al cliente como el que
-- dejó en garantía, cada uno como su propia fila de bal_prestamo_detalle.
--
-- De paso, corrige un bug preexistente sin relación con lo anterior: el INSERT
-- escribía en la columna "id_guia_devolucion", que ya no existe (Fase 2 la
-- renombró a "id_doc_salida_devolucion" al migrar de gre_guia_remision a
-- doc_salida; el par "id_doc_salida_entrega" sí se corrigió, este no). Cualquier
-- llamada a esta función fallaba con "column id_guia_devolucion does not exist".
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin chequeo de bal_alquiler_detalle (el cilindro nunca se alquila).
DROP FUNCTION IF EXISTS bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer, p_id_producto integer, p_motivo_especifico character varying, p_fecha_entregado date, p_fecha_prestamo date, p_dias_prestamo integer, p_fecha_vencimiento date, p_fecha_devolucion date, p_serie_guia_entrega character varying, p_numero_guia_entrega character varying, p_serie_guia_devolucion character varying, p_numero_guia_devolucion character varying, p_id_estado integer, p_observacion character varying, p_id_usuario_auditoria integer, p_id_guia_entrega integer, p_id_guia_devolucion integer);

CREATE OR REPLACE FUNCTION bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_motivo_especifico character varying DEFAULT NULL::character varying, p_fecha_entregado date DEFAULT NULL::date, p_fecha_prestamo date DEFAULT NULL::date, p_dias_prestamo integer DEFAULT 30, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_devolucion date DEFAULT NULL::date, p_serie_guia_entrega character varying DEFAULT NULL::character varying, p_numero_guia_entrega character varying DEFAULT NULL::character varying, p_serie_guia_devolucion character varying DEFAULT NULL::character varying, p_numero_guia_devolucion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_guia_entrega integer DEFAULT NULL::integer, p_id_guia_devolucion integer DEFAULT NULL::integer, p_rol character varying DEFAULT 'ENTREGADO'::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_producto INTEGER;
    v_id_estado_detalle INTEGER;
    v_salida JSON;
    v_serie_entrega VARCHAR;
    v_numero_entrega VARCHAR;
    v_serie_devolucion VARCHAR;
    v_numero_devolucion VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_id_producto := p_id_producto;
    v_id_estado_detalle := p_id_estado;
    v_serie_entrega := p_serie_guia_entrega;
    v_numero_entrega := p_numero_guia_entrega;
    v_serie_devolucion := p_serie_guia_devolucion;
    v_numero_devolucion := p_numero_guia_devolucion;

    -- Serie/número quedan como snapshot de la GRE vinculada (compatibilidad UI).
    IF p_id_guia_entrega IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_entrega, v_numero_entrega
        FROM doc_salida g
        WHERE g.id = p_id_guia_entrega AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de entrega indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF p_id_guia_devolucion IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_devolucion, v_numero_devolucion
        FROM doc_salida g
        WHERE g.id = p_id_guia_devolucion AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de devolución indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF v_id_estado_detalle IS NULL AND p_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_detalle
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    IF p_id_balon IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(b.id_producto_gas, v_id_producto) INTO v_id_producto
        FROM bal_balon b
        WHERE b.id = p_id_balon AND b.estado = 1;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un préstamo activo sin devolver',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo_detalle (
        id_prestamo, id_balon, id_producto, motivo_especifico,
        fecha_entregado, fecha_prestamo, dias_prestamo, fecha_vencimiento, fecha_devolucion,
        id_doc_salida_entrega, id_doc_salida_devolucion,
        serie_guia_entrega, numero_guia_entrega, serie_guia_devolucion, numero_guia_devolucion,
        id_estado, observacion, rol,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_prestamo, p_id_balon, v_id_producto, p_motivo_especifico,
        p_fecha_entregado, p_fecha_prestamo, COALESCE(p_dias_prestamo, 30), p_fecha_vencimiento, p_fecha_devolucion,
        p_id_guia_entrega, p_id_guia_devolucion,
        v_serie_entrega, v_numero_entrega, v_serie_devolucion, v_numero_devolucion,
        v_id_estado_detalle, p_observacion, COALESCE(p_rol, 'ENTREGADO'),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Histórico ya devuelto: no mueve custodia. Activo: sale del almacén.
    -- Rol GARANTIA es al revés (el cilindro ENTRA a custodia de Sarita, no sale) —
    -- ese movimiento lo registra quien llama (ven_aplicar_efectos_pos), no aquí.
    IF p_id_balon IS NOT NULL AND p_fecha_devolucion IS NULL AND COALESCE(p_rol, 'ENTREGADO') = 'ENTREGADO' THEN
        v_salida := bal_prestamo_aplicar_salida_cilindro(
            p_id_prestamo,
            p_id_balon,
            p_observacion,
            p_id_usuario_auditoria
        );

        IF v_salida->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_salida->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_prestamo_detalle(v_id);
END;
$function$;

-- ===== funciones\prestamos-detalle\bal_actualizar_prestamo_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin chequeo de bal_alquiler_detalle (el cilindro nunca se alquila).
DROP FUNCTION IF EXISTS bal_actualizar_prestamo_detalle(p_id integer, p_id_balon integer, p_id_producto integer, p_motivo_especifico character varying, p_fecha_entregado date, p_fecha_prestamo date, p_dias_prestamo integer, p_fecha_vencimiento date, p_fecha_devolucion date, p_serie_guia_entrega character varying, p_numero_guia_entrega character varying, p_serie_guia_devolucion character varying, p_numero_guia_devolucion character varying, p_id_estado integer, p_observacion character varying, p_id_usuario_auditoria integer, p_id_guia_entrega integer, p_id_guia_devolucion integer);

CREATE OR REPLACE FUNCTION bal_actualizar_prestamo_detalle(p_id integer, p_id_balon integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_motivo_especifico character varying DEFAULT NULL::character varying, p_fecha_entregado date DEFAULT NULL::date, p_fecha_prestamo date DEFAULT NULL::date, p_dias_prestamo integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_devolucion date DEFAULT NULL::date, p_serie_guia_entrega character varying DEFAULT NULL::character varying, p_numero_guia_entrega character varying DEFAULT NULL::character varying, p_serie_guia_devolucion character varying DEFAULT NULL::character varying, p_numero_guia_devolucion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_guia_entrega integer DEFAULT NULL::integer, p_id_guia_devolucion integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_serie_entrega VARCHAR;
    v_numero_entrega VARCHAR;
    v_serie_devolucion VARCHAR;
    v_numero_devolucion VARCHAR;
    v_id_prestamo INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen INTEGER;
    v_id_cliente INTEGER;
    v_id_balon_nuevo INTEGER;
    v_id_producto INTEGER;
    v_nombre_estado_nuevo VARCHAR;
    v_retorno JSON;
    v_salida JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.id_producto,
        p.id_almacen,
        p.id_cliente
    INTO
        v_id_prestamo,
        v_id_balon_actual,
        v_fecha_devolucion,
        v_id_producto,
        v_id_almacen,
        v_id_cliente
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id AND pd.estado = 1;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object('error', 'El detalle de préstamo no existe o está inactivo', 'registro', NULL);
    END IF;

    v_serie_entrega := p_serie_guia_entrega;
    v_numero_entrega := p_numero_guia_entrega;
    v_serie_devolucion := p_serie_guia_devolucion;
    v_numero_devolucion := p_numero_guia_devolucion;

    -- Serie/número quedan como snapshot de la GRE vinculada (compatibilidad UI).
    IF p_id_guia_entrega IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_entrega, v_numero_entrega
        FROM doc_salida g
        WHERE g.id = p_id_guia_entrega AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de entrega indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF p_id_guia_devolucion IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_devolucion, v_numero_devolucion
        FROM doc_salida g
        WHERE g.id = p_id_guia_devolucion AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de devolución indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    -- El vínculo GRE se aplica antes de cualquier bifurcación para que también
    -- quede grabado cuando la actualización delega en la devolución.
    IF p_id_guia_entrega IS NOT NULL OR p_id_guia_devolucion IS NOT NULL THEN
        UPDATE bal_prestamo_detalle
        SET
            id_doc_salida_entrega = COALESCE(p_id_guia_entrega, id_doc_salida_entrega),
            id_doc_salida_devolucion = COALESCE(p_id_guia_devolucion, id_doc_salida_devolucion),
            serie_guia_entrega = COALESCE(v_serie_entrega, serie_guia_entrega),
            numero_guia_entrega = COALESCE(v_numero_entrega, numero_guia_entrega),
            serie_guia_devolucion = COALESCE(v_serie_devolucion, serie_guia_devolucion),
            numero_guia_devolucion = COALESCE(v_numero_devolucion, numero_guia_devolucion),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id AND estado = 1;
    END IF;

    v_id_balon_nuevo := COALESCE(p_id_balon, v_id_balon_actual);

    IF p_id_estado IS NOT NULL THEN
        SELECT lo.nombre INTO v_nombre_estado_nuevo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_estado AND lo.estado = 1;
    END IF;

    -- Devolver por fecha/estado en el formulario de edición → misma custodia que "Devolver".
    IF v_fecha_devolucion IS NULL
       AND (
           p_fecha_devolucion IS NOT NULL
           OR UPPER(COALESCE(v_nombre_estado_nuevo, '')) = 'DEVUELTO'
       )
    THEN
        RETURN bal_devolver_prestamo_detalle(
            p_id,
            COALESCE(p_fecha_devolucion, CURRENT_DATE),
            v_id_almacen,
            p_id_usuario_auditoria,
            'VACIO',
            p_observacion
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL
       AND p_id_balon IS NOT NULL
       AND p_id_balon IS DISTINCT FROM v_id_balon_actual
    THEN
        RETURN json_build_object(
            'error', 'No se puede cambiar el cilindro de un detalle ya devuelto',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NULL
       AND p_id_balon IS NOT NULL
       AND p_id_balon IS DISTINCT FROM v_id_balon_actual
    THEN
        IF v_id_balon_actual IS NOT NULL THEN
            IF v_id_almacen IS NULL THEN
                SELECT id INTO v_id_almacen FROM gen_almacen WHERE estado = 1 ORDER BY id LIMIT 1;
            END IF;

            v_retorno := bal_prestamo_aplicar_retorno_cilindro(
                v_id_balon_actual,
                v_id_prestamo,
                v_id_cliente,
                v_id_almacen,
                NULL,
                'Cambio de cilindro en préstamo (libera el anterior)',
                p_id_usuario_auditoria,
                TRUE
            );
            IF v_retorno->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_retorno->>'error', 'registro', NULL);
            END IF;
        END IF;

        -- Tras liberar el cilindro anterior, cualquier fallo debe abortar con
        -- RAISE para revertir el retorno (nunca soft RETURN post-mutación).
        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon_nuevo
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
              AND pd.id <> p_id
        ) THEN
            RAISE EXCEPTION 'El cilindro ya tiene un préstamo activo sin devolver';
        END IF;

        v_salida := bal_prestamo_aplicar_salida_cilindro(
            v_id_prestamo,
            v_id_balon_nuevo,
            COALESCE(p_observacion, 'Cambio de cilindro en préstamo'),
            p_id_usuario_auditoria
        );
        IF v_salida->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_salida->>'error';
        END IF;
    END IF;

    IF v_id_balon_nuevo IS NOT NULL THEN
        SELECT COALESCE(b.id_producto_gas, COALESCE(p_id_producto, v_id_producto))
        INTO v_id_producto
        FROM bal_balon b
        WHERE b.id = v_id_balon_nuevo AND b.estado = 1;
    ELSE
        v_id_producto := COALESCE(p_id_producto, v_id_producto);
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_producto = COALESCE(v_id_producto, id_producto),
        motivo_especifico = COALESCE(p_motivo_especifico, motivo_especifico),
        fecha_entregado = COALESCE(p_fecha_entregado, fecha_entregado),
        fecha_prestamo = COALESCE(p_fecha_prestamo, fecha_prestamo),
        dias_prestamo = COALESCE(p_dias_prestamo, dias_prestamo),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        id_doc_salida_entrega = COALESCE(p_id_guia_entrega, id_doc_salida_entrega),
        id_doc_salida_devolucion = COALESCE(p_id_guia_devolucion, id_doc_salida_devolucion),
        serie_guia_entrega = COALESCE(v_serie_entrega, serie_guia_entrega),
        numero_guia_entrega = COALESCE(v_numero_entrega, numero_guia_entrega),
        serie_guia_devolucion = COALESCE(v_serie_devolucion, serie_guia_devolucion),
        numero_guia_devolucion = COALESCE(v_numero_devolucion, numero_guia_devolucion),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_prestamo_detalle(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte retorno/salida parcial de cambio de cilindro y expone al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;

-- ===== funciones\clientes\cli_listar_clientes_mapa.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_listar_clientes_mapa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.952Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin lateral sobre bal_alquiler_detalle (el cilindro nunca se alquila; solo préstamo).
DROP FUNCTION IF EXISTS cli_listar_clientes_mapa(p_solo_activos integer, p_buscar character varying, p_filtro_balones character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION cli_listar_clientes_mapa(p_solo_activos integer DEFAULT 1, p_buscar character varying DEFAULT NULL::character varying, p_filtro_balones character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 500, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_filtro    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');
    v_filtro := NULLIF(UPPER(TRIM(p_filtro_balones)), '');

    WITH balones_campo AS (
        SELECT
            x.id_cliente,
            x.id_balon,
            x.codigo_balon,
            x.numero_serie,
            x.nombre_estado_balon,
            x.nombre_tipo_balon,
            x.tipo_relacion,
            x.fecha_inicio,
            x.fecha_limite,
            x.dias_en_cliente,
            x.vencido,
            x.alerta_antiguedad
        FROM (
            SELECT
                COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) AS id_cliente,
                b.id AS id_balon,
                b.codigo_balon,
                b.numero_serie,
                eb.nombre AS nombre_estado_balon,
                tb.nombre AS nombre_tipo_balon,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN 'PRESTAMO'
                    WHEN 'POR_RECOGER' THEN 'PRESTAMO'
                    WHEN 'ALQUILADO' THEN 'ALQUILER'
                    WHEN 'EN_PODER_CLIENTE' THEN 'PROPIO'
                    ELSE eb.nombre
                END AS tipo_relacion,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                        THEN COALESCE(prest.fecha_inicio, b.fecha_modificacion::date)
                    WHEN eb.nombre = 'ALQUILADO'
                        THEN COALESCE(NULL::date, b.fecha_modificacion::date)
                    ELSE NULL
                END AS fecha_inicio,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_limite
                    WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                    ELSE NULL
                END AS fecha_limite,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO')
                         AND COALESCE(
                             CASE
                                 WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                 WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                             END,
                             b.fecha_modificacion::date
                         ) IS NOT NULL
                    THEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    )::INTEGER
                    ELSE NULL
                END AS dias_en_cliente,
                CASE
                    WHEN eb.nombre = 'ALQUILADO'
                         AND NULL::date IS NOT NULL
                         AND CURRENT_DATE > NULL::date
                    THEN TRUE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                         AND prest.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > prest.fecha_limite
                    THEN TRUE
                    ELSE FALSE
                END AS vencido,
                CASE
                    WHEN eb.nombre NOT IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO') THEN NULL
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 180 THEN 'CRITICO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 90 THEN 'SEGUIMIENTO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 30 THEN 'ATENCION'
                    ELSE 'RECIENTE'
                END AS alerta_antiguedad
            FROM bal_balon b
            INNER JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
            LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(pd.fecha_prestamo, pd.fecha_entregado, pr.fecha_salida) AS fecha_inicio,
                    pd.fecha_vencimiento AS fecha_limite
                FROM bal_prestamo_detalle pd
                INNER JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
                WHERE pd.id_balon = b.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pr.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY pd.id DESC
                LIMIT 1
            ) prest ON TRUE
            WHERE b.estado = 1
              -- ALQUILADO ya no existe como custodia: el cilindro nunca se alquila.
              AND eb.nombre IN (
                  'PRESTADO_CLIENTE',
                  'POR_RECOGER',
                  'EN_PODER_CLIENTE'
              )
              AND COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) IS NOT NULL
        ) x
    ),
    balones_agg AS (
        SELECT
            bc.id_cliente,
            json_agg(
                json_build_object(
                    'id_balon', bc.id_balon,
                    'codigo_balon', bc.codigo_balon,
                    'numero_serie', bc.numero_serie,
                    'nombre_estado_balon', bc.nombre_estado_balon,
                    'nombre_tipo_balon', bc.nombre_tipo_balon,
                    'tipo_relacion', bc.tipo_relacion,
                    'fecha_inicio', bc.fecha_inicio,
                    'fecha_limite', bc.fecha_limite,
                    'dias_en_cliente', bc.dias_en_cliente,
                    'vencido', bc.vencido,
                    'alerta_antiguedad', bc.alerta_antiguedad
                )
                ORDER BY
                    CASE WHEN bc.vencido THEN 0 ELSE 1 END,
                    bc.dias_en_cliente DESC NULLS LAST,
                    bc.codigo_balon
            ) AS balones,
            COUNT(*)::INT AS total_balones,
            BOOL_OR(bc.tipo_relacion = 'PRESTAMO') AS tiene_prestamo,
            BOOL_OR(bc.tipo_relacion = 'ALQUILER') AS tiene_alquiler,
            BOOL_OR(bc.tipo_relacion = 'PROPIO') AS tiene_propio,
            BOOL_OR(COALESCE(bc.vencido, FALSE)) AS tiene_vencidos,
            MAX(bc.dias_en_cliente) AS max_dias_en_cliente
        FROM (
            SELECT DISTINCT ON (id_cliente, id_balon)
                id_cliente,
                id_balon,
                codigo_balon,
                numero_serie,
                nombre_estado_balon,
                nombre_tipo_balon,
                tipo_relacion,
                fecha_inicio,
                fecha_limite,
                dias_en_cliente,
                vencido,
                alerta_antiguedad
            FROM balones_campo
            ORDER BY id_cliente, id_balon, tipo_relacion
        ) bc
        GROUP BY bc.id_cliente
    ),
    filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.numero_documento,
            tp.nombre AS nombre_tipo_persona,
            c.telefono,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            c.estado,
            COALESCE(ba.balones, '[]'::json) AS balones,
            COALESCE(ba.total_balones, 0) AS total_balones,
            COALESCE(ba.tiene_prestamo, FALSE) AS tiene_prestamo,
            COALESCE(ba.tiene_alquiler, FALSE) AS tiene_alquiler,
            COALESCE(ba.tiene_propio, FALSE) AS tiene_propio,
            COALESCE(ba.tiene_vencidos, FALSE) AS tiene_vencidos,
            ba.max_dias_en_cliente
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        -- Dirección a dibujar: la principal si tiene coordenadas; si no, la
        -- georreferenciada más reciente (ej. la marcada desde una orden de salida).
        INNER JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.estado = 1
              AND cd.latitud IS NOT NULL
              AND cd.longitud IS NOT NULL
            ORDER BY cd.es_principal DESC, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN balones_agg ba ON ba.id_cliente = c.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(c.razon_social, v_buscar)
                OR gen_texto_coincide(c.nombres, v_buscar)
                OR gen_texto_coincide(c.apellido_paterno, v_buscar)
                OR gen_texto_coincide(c.apellido_materno, v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
                OR gen_texto_coincide(c.codigo_interno, v_buscar)
                OR gen_texto_coincide(dir.direccion, v_buscar)
              )
          AND (
                v_filtro IS NULL
                OR (v_filtro = 'CON_BALONES' AND COALESCE(ba.total_balones, 0) > 0)
                OR (v_filtro = 'PRESTADO_CLIENTE' AND COALESCE(ba.tiene_prestamo, FALSE))
                OR (v_filtro = 'ALQUILADO' AND COALESCE(ba.tiene_alquiler, FALSE))
                OR (v_filtro = 'EN_PODER_CLIENTE' AND COALESCE(ba.tiene_propio, FALSE))
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            CASE WHEN tiene_vencidos THEN 0 ELSE 1 END,
            total_balones DESC,
            razon_social NULLS LAST,
            nombres NULLS LAST,
            id DESC
        LIMIT GREATEST(COALESCE(p_limite, 500), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- ===== funciones\mantenimientos\bal_eliminar_mantenimiento.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin rama de restauración a ALQUILADO (bal_alquiler_detalle eliminada).
DROP FUNCTION IF EXISTS bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
    v_id_comprobante_compra INTEGER;
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_comprobante_venta,
        m.id_comprobante_compra,
        m.id_balon,
        em.nombre,
        b.id_almacen
    INTO
        v_id_comprobante_venta,
        v_id_comprobante_compra,
        v_id_balon,
        v_nombre_estado,
        v_id_almacen
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL OR v_id_comprobante_compra IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_mantenimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene historial de P.H. asociado'
        );
    END IF;

    UPDATE bal_mantenimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si no estaba finalizado, restaurar custodia previa (alquiler / préstamo / almacén).
    IF v_id_balon IS NOT NULL AND UPPER(COALESCE(v_nombre_estado, '')) <> 'FINALIZADO' THEN
        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT p2.id_cliente
                    FROM bal_prestamo_detalle pd
                    INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo
                    WHERE pd.id_balon = v_id_balon
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                    ORDER BY pd.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSE
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_en_almacen IS NOT NULL THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_en_almacen,
                    id_almacen = COALESCE(id_almacen, v_id_almacen),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_balon
                  AND estado = 1
                  AND EXISTS (
                      SELECT 1
                      FROM gen_lista_opciones eb
                      WHERE eb.id = bal_balon.id_estado_balon
                        AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
                  )
                  AND NOT EXISTS (
                      SELECT 1
                      FROM bal_mantenimiento m2
                      LEFT JOIN gen_lista_opciones em2 ON em2.id = m2.id_estado
                      WHERE m2.id_balon = v_id_balon
                        AND m2.id <> p_id
                        AND m2.estado = 1
                        AND UPPER(COALESCE(em2.nombre, '')) <> 'FINALIZADO'
                  );
            END IF;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- DROP funciones del detalle de alquiler y del KPI de balones alquilados
-- ============================================================
DO $mig$
DECLARE v_f RECORD;
BEGIN
    FOR v_f IN
        SELECT p.oid::regprocedure AS firma
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'bal_actualizar_alquiler_detalle',
              'bal_crear_alquiler_detalle',
              'bal_devolver_alquiler_detalle',
              'bal_eliminar_alquiler_detalle',
              'bal_listar_alquiler_detalles',
              'bal_obtener_alquiler_detalle',
              'dash_balones_alquilados'
          )
    LOOP
        EXECUTE format('DROP FUNCTION %s', v_f.firma);
    END LOOP;
END
$mig$;

-- ============================================================
-- DROP tabla y columna
-- ============================================================
ALTER TABLE age_actividad_item DROP COLUMN IF EXISTS id_alquiler_detalle;
DROP TABLE IF EXISTS bal_alquiler_detalle;

-- ============================================================
-- Permisos alquileres_detalle.*
-- ============================================================
DELETE FROM auth_roles_permisos rp
USING auth_permisos p
WHERE p.id = rp.id_permiso
  AND p.nombre LIKE 'alquileres_detalle.%';

DELETE FROM auth_permisos
WHERE nombre LIKE 'alquileres_detalle.%';
