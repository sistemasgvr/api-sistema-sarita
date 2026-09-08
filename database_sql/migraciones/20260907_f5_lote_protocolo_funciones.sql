-- ============================================================
-- Migración: Fase 5 — funciones de lote y protocolo (ficha ICP)
-- Fecha: 2026-09-07
--
-- Requiere 20260907_f5_lote_protocolo.sql (tablas y columnas nuevas).
--
-- Además de las funciones nuevas del dominio, vuelve a crear cuatro funciones
-- existentes que ahora aceptan la ficha:
--   · bal_crear_movimiento_recarga / bal_actualizar_movimiento_recarga
--   · bal_finalizar_recarga_planta
--   · bal_obtener_balon (expone la ficha vigente del cilindro)
-- En las tres primeras el parámetro p_id_lote_protocolo se añade AL FINAL de la
-- firma, para que las llamadas posicionales que ya existen sigan siendo válidas.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260907_f5_lote_protocolo_funciones.sql
-- ============================================================



-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_reemplazar_lote_protocolo_detalle.sql
-- ============================================================

-- Function: bal_reemplazar_lote_protocolo_detalle
-- Fase 5 — punto único de escritura del detalle de una ficha ICP (pruebas y
-- envases). Lo usan crear y actualizar, para que ambas dejen exactamente el
-- mismo estado y la regla de "match por número de serie" viva en un solo sitio.
--
-- p_pruebas / p_envases NULL = no tocar ese bloque. Un array vacío sí lo vacía.
DROP FUNCTION IF EXISTS bal_reemplazar_lote_protocolo_detalle(p_id_lote_protocolo integer, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_reemplazar_lote_protocolo_detalle(p_id_lote_protocolo integer, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_pruebas INTEGER := 0;
    v_total_envases INTEGER := 0;
    v_vinculados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pruebas IS NOT NULL THEN
        UPDATE bal_lote_protocolo_prueba
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_lote_protocolo = p_id_lote_protocolo AND estado = 1;

        INSERT INTO bal_lote_protocolo_prueba (
            id_lote_protocolo, orden, prueba, especificacion, resultado,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_lote_protocolo,
            COALESCE((x->>'orden')::INT, ordinalidad::INT),
            NULLIF(TRIM(x->>'prueba'), ''),
            NULLIF(TRIM(x->>'especificacion'), ''),
            NULLIF(TRIM(x->>'resultado'), ''),
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM json_array_elements(p_pruebas) WITH ORDINALITY AS a(x, ordinalidad)
        WHERE NULLIF(TRIM(x->>'prueba'), '') IS NOT NULL;

        GET DIAGNOSTICS v_total_pruebas = ROW_COUNT;
    END IF;

    IF p_envases IS NOT NULL THEN
        UPDATE bal_lote_protocolo_envase
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_lote_protocolo = p_id_lote_protocolo AND estado = 1;

        -- El envase puede venir como objeto {serieEnvase} o como serie suelta:
        -- la relación del PDF es una lista de series, no de objetos.
        INSERT INTO bal_lote_protocolo_envase (
            id_lote_protocolo, serie_envase, id_balon,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_lote_protocolo,
            s.serie,
            (
                SELECT b.id
                FROM bal_balon b
                WHERE b.estado = 1
                  AND UPPER(TRIM(COALESCE(b.numero_serie, ''))) = UPPER(s.serie)
                ORDER BY b.id
                LIMIT 1
            ),
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM (
            SELECT DISTINCT UPPER(TRIM(COALESCE(x->>'serieEnvase', x->>'serie_envase', x#>>'{}'))) AS serie
            FROM json_array_elements(p_envases) AS a(x)
        ) s
        WHERE NULLIF(s.serie, '') IS NOT NULL
        ON CONFLICT (id_lote_protocolo, serie_envase) DO UPDATE
        SET estado = 1,
            id_balon = EXCLUDED.id_balon,
            id_usuario_modificacion = EXCLUDED.id_usuario_modificacion,
            fecha_modificacion = NOW();

        GET DIAGNOSTICS v_total_envases = ROW_COUNT;

        SELECT COUNT(*)::INT INTO v_vinculados
        FROM bal_lote_protocolo_envase e
        WHERE e.id_lote_protocolo = p_id_lote_protocolo
          AND e.estado = 1
          AND e.id_balon IS NOT NULL;
    END IF;

    RETURN json_build_object(
        'total_pruebas', v_total_pruebas,
        'total_envases', v_total_envases,
        'total_envases_vinculados', v_vinculados
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_obtener_lote_protocolo.sql
-- ============================================================

-- Function: bal_obtener_lote_protocolo
-- Fase 5 — ficha ICP completa: cabecera + datos de análisis + envases aprobados.
DROP FUNCTION IF EXISTS bal_obtener_lote_protocolo(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_lote_protocolo(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_pruebas JSON;
    v_envases JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            lp.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            lp.descripcion_producto,
            lp.forma_farmaceutica,
            lp.presentacion,
            lp.norma_tecnica,
            lp.metodo_fabricacion,
            lp.fecha_analisis,
            lp.fecha_emision,
            lp.fecha_fabricacion,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.tamano_lote_m3,
            lp.cantidad_envases,
            lp.valoracion_o2_pct,
            lp.limite_co2_ppm,
            lp.limite_co_ppm,
            lp.cilindro_muestreado_serie,
            lp.temperatura_muestreo_c,
            lp.presion_muestreo_psi,
            lp.analista,
            lp.conclusion,
            lp.codigo_documento,
            lp.version_documento,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            ar.nombre_original AS nombre_archivo_pdf,
            ar.bucket AS bucket_archivo_pdf,
            lp.observacion,
            (
                SELECT COUNT(*)::INT
                FROM bal_balon b
                WHERE b.id_lote_protocolo_vigente = lp.id AND b.estado = 1
            ) AS total_balones_vigentes,
            lp.fecha_creacion,
            lp.fecha_modificacion
        FROM bal_lote_protocolo lp
        LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
        LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE lp.id = p_id AND lp.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.orden, pr.id), '[]'::JSON)
    INTO v_pruebas
    FROM (
        SELECT p.id, p.orden, p.prueba, p.especificacion, p.resultado
        FROM bal_lote_protocolo_prueba p
        WHERE p.id_lote_protocolo = p_id AND p.estado = 1
        ORDER BY p.orden, p.id
    ) pr;

    SELECT COALESCE(json_agg(row_to_json(en) ORDER BY en.serie_envase), '[]'::JSON)
    INTO v_envases
    FROM (
        SELECT
            e.id,
            e.serie_envase,
            e.id_balon,
            b.codigo_balon,
            tb.nombre AS nombre_tipo_balon,
            eb.nombre AS nombre_estado_balon,
            (b.id_lote_protocolo_vigente = p_id) AS es_lote_vigente
        FROM bal_lote_protocolo_envase e
        LEFT JOIN bal_balon b ON b.id = e.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE e.id_lote_protocolo = p_id AND e.estado = 1
        ORDER BY e.serie_envase
    ) en;

    RETURN json_build_object(
        'error', NULL,
        'registro', (
            v_registro::JSONB
            || jsonb_build_object('pruebas', v_pruebas, 'envases', v_envases)
        )::JSON
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_listar_lotes_protocolo.sql
-- ============================================================

-- Function: bal_listar_lotes_protocolo
-- Fase 5 — fichas ICP de oxígeno medicinal (lote + protocolo).
DROP FUNCTION IF EXISTS bal_listar_lotes_protocolo(p_busqueda character varying, p_limite integer, p_offset integer, p_id_proveedor integer, p_id_producto_gas integer, p_vencidos boolean, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_lotes_protocolo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_vencidos boolean DEFAULT NULL::boolean, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*)
    INTO v_total
    FROM bal_lote_protocolo lp
    LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
    LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
    WHERE lp.estado = 1
      AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
      AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
      AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
      AND (
          p_vencidos IS NULL
          OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
          OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pv.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            lp.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            lp.descripcion_producto,
            lp.presentacion,
            lp.fecha_analisis,
            lp.fecha_emision,
            lp.fecha_fabricacion,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.tamano_lote_m3,
            lp.cantidad_envases,
            lp.valoracion_o2_pct,
            lp.cilindro_muestreado_serie,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            ar.nombre_original AS nombre_archivo_pdf,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1
            ) AS total_envases,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1 AND e.id_balon IS NOT NULL
            ) AS total_envases_vinculados,
            (
                SELECT COUNT(*)::INT
                FROM bal_balon b
                WHERE b.id_lote_protocolo_vigente = lp.id AND b.estado = 1
            ) AS total_balones_vigentes,
            lp.fecha_creacion,
            lp.fecha_modificacion
        FROM bal_lote_protocolo lp
        LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
        LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE lp.estado = 1
          AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
          AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
          AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
          AND (
              p_vencidos IS NULL
              OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
              OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pv.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
          )
        ORDER BY lp.fecha_emision DESC NULLS LAST, lp.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 10), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_crear_lote_protocolo.sql
-- ============================================================

-- Function: bal_crear_lote_protocolo
-- Fase 5 — alta de una ficha ICP. Los datos de análisis y la relación de envases
-- llegan como JSON en el mismo llamado: la ficha no tiene sentido a medias.
DROP FUNCTION IF EXISTS bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying, p_id_proveedor integer, p_id_producto_gas integer, p_descripcion_producto character varying, p_forma_farmaceutica character varying, p_presentacion character varying, p_norma_tecnica character varying, p_metodo_fabricacion character varying, p_fecha_analisis date, p_fecha_emision date, p_fecha_fabricacion date, p_fecha_vencimiento date, p_tamano_lote_m3 numeric, p_cantidad_envases integer, p_valoracion_o2_pct numeric, p_limite_co2_ppm numeric, p_limite_co_ppm numeric, p_cilindro_muestreado_serie character varying, p_temperatura_muestreo_c numeric, p_presion_muestreo_psi numeric, p_analista character varying, p_conclusion character varying, p_codigo_documento character varying, p_version_documento character varying, p_id_archivo_pdf integer, p_observacion character varying, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying DEFAULT NULL::character varying, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_descripcion_producto character varying DEFAULT NULL::character varying, p_forma_farmaceutica character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_norma_tecnica character varying DEFAULT NULL::character varying, p_metodo_fabricacion character varying DEFAULT NULL::character varying, p_fecha_analisis date DEFAULT NULL::date, p_fecha_emision date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_tamano_lote_m3 numeric DEFAULT NULL::numeric, p_cantidad_envases integer DEFAULT NULL::integer, p_valoracion_o2_pct numeric DEFAULT NULL::numeric, p_limite_co2_ppm numeric DEFAULT NULL::numeric, p_limite_co_ppm numeric DEFAULT NULL::numeric, p_cilindro_muestreado_serie character varying DEFAULT NULL::character varying, p_temperatura_muestreo_c numeric DEFAULT NULL::numeric, p_presion_muestreo_psi numeric DEFAULT NULL::numeric, p_analista character varying DEFAULT NULL::character varying, p_conclusion character varying DEFAULT NULL::character varying, p_codigo_documento character varying DEFAULT NULL::character varying, p_version_documento character varying DEFAULT NULL::character varying, p_id_archivo_pdf integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero_lote VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero_lote := NULLIF(TRIM(p_numero_lote), '');

    IF v_numero_lote IS NULL THEN
        RETURN json_build_object('error', 'El número de lote es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND UPPER(TRIM(lp.numero_lote)) = UPPER(v_numero_lote)
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
    ) THEN
        RETURN json_build_object(
            'error', format('Ya existe una ficha activa con el lote %s para ese proveedor', v_numero_lote),
            'registro', NULL
        );
    END IF;

    INSERT INTO bal_lote_protocolo (
        numero_lote, numero_protocolo, id_proveedor, id_producto_gas,
        descripcion_producto, forma_farmaceutica, presentacion, norma_tecnica,
        metodo_fabricacion, fecha_analisis, fecha_emision, fecha_fabricacion,
        fecha_vencimiento, tamano_lote_m3, cantidad_envases, valoracion_o2_pct,
        limite_co2_ppm, limite_co_ppm, cilindro_muestreado_serie,
        temperatura_muestreo_c, presion_muestreo_psi, analista, conclusion,
        codigo_documento, version_documento, id_archivo_pdf, observacion,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_numero_lote, NULLIF(TRIM(p_numero_protocolo), ''), p_id_proveedor, p_id_producto_gas,
        p_descripcion_producto, p_forma_farmaceutica, p_presentacion, p_norma_tecnica,
        p_metodo_fabricacion, p_fecha_analisis, p_fecha_emision, p_fecha_fabricacion,
        p_fecha_vencimiento, p_tamano_lote_m3, p_cantidad_envases, p_valoracion_o2_pct,
        p_limite_co2_ppm, p_limite_co_ppm, NULLIF(TRIM(p_cilindro_muestreado_serie), ''),
        p_temperatura_muestreo_c, p_presion_muestreo_psi, p_analista, p_conclusion,
        p_codigo_documento, p_version_documento, p_id_archivo_pdf, p_observacion,
        1, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM bal_reemplazar_lote_protocolo_detalle(v_id, p_pruebas, p_envases, p_id_usuario_auditoria);

    RETURN bal_obtener_lote_protocolo(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_actualizar_lote_protocolo.sql
-- ============================================================

-- Function: bal_actualizar_lote_protocolo
-- Fase 5 — edición de la ficha ICP. Los campos NULL no se tocan (COALESCE);
-- pruebas y envases se reemplazan solo si vienen en el llamado.
DROP FUNCTION IF EXISTS bal_actualizar_lote_protocolo(p_id integer, p_numero_lote character varying, p_numero_protocolo character varying, p_id_proveedor integer, p_id_producto_gas integer, p_descripcion_producto character varying, p_forma_farmaceutica character varying, p_presentacion character varying, p_norma_tecnica character varying, p_metodo_fabricacion character varying, p_fecha_analisis date, p_fecha_emision date, p_fecha_fabricacion date, p_fecha_vencimiento date, p_tamano_lote_m3 numeric, p_cantidad_envases integer, p_valoracion_o2_pct numeric, p_limite_co2_ppm numeric, p_limite_co_ppm numeric, p_cilindro_muestreado_serie character varying, p_temperatura_muestreo_c numeric, p_presion_muestreo_psi numeric, p_analista character varying, p_conclusion character varying, p_codigo_documento character varying, p_version_documento character varying, p_id_archivo_pdf integer, p_observacion character varying, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_lote_protocolo(p_id integer, p_numero_lote character varying DEFAULT NULL::character varying, p_numero_protocolo character varying DEFAULT NULL::character varying, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_descripcion_producto character varying DEFAULT NULL::character varying, p_forma_farmaceutica character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_norma_tecnica character varying DEFAULT NULL::character varying, p_metodo_fabricacion character varying DEFAULT NULL::character varying, p_fecha_analisis date DEFAULT NULL::date, p_fecha_emision date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_tamano_lote_m3 numeric DEFAULT NULL::numeric, p_cantidad_envases integer DEFAULT NULL::integer, p_valoracion_o2_pct numeric DEFAULT NULL::numeric, p_limite_co2_ppm numeric DEFAULT NULL::numeric, p_limite_co_ppm numeric DEFAULT NULL::numeric, p_cilindro_muestreado_serie character varying DEFAULT NULL::character varying, p_temperatura_muestreo_c numeric DEFAULT NULL::numeric, p_presion_muestreo_psi numeric DEFAULT NULL::numeric, p_analista character varying DEFAULT NULL::character varying, p_conclusion character varying DEFAULT NULL::character varying, p_codigo_documento character varying DEFAULT NULL::character varying, p_version_documento character varying DEFAULT NULL::character varying, p_id_archivo_pdf integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero_lote VARCHAR;
    v_id_proveedor INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    SELECT
        COALESCE(NULLIF(TRIM(p_numero_lote), ''), lp.numero_lote),
        COALESCE(p_id_proveedor, lp.id_proveedor)
    INTO v_numero_lote, v_id_proveedor
    FROM bal_lote_protocolo lp
    WHERE lp.id = p_id;

    IF EXISTS (
        SELECT 1 FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND lp.id <> p_id
          AND UPPER(TRIM(lp.numero_lote)) = UPPER(v_numero_lote)
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(v_id_proveedor, 0)
    ) THEN
        RETURN json_build_object(
            'error', format('Ya existe otra ficha activa con el lote %s para ese proveedor', v_numero_lote),
            'registro', NULL
        );
    END IF;

    UPDATE bal_lote_protocolo
    SET numero_lote               = v_numero_lote,
        numero_protocolo          = COALESCE(NULLIF(TRIM(p_numero_protocolo), ''), numero_protocolo),
        id_proveedor              = COALESCE(p_id_proveedor, id_proveedor),
        id_producto_gas           = COALESCE(p_id_producto_gas, id_producto_gas),
        descripcion_producto      = COALESCE(p_descripcion_producto, descripcion_producto),
        forma_farmaceutica        = COALESCE(p_forma_farmaceutica, forma_farmaceutica),
        presentacion              = COALESCE(p_presentacion, presentacion),
        norma_tecnica             = COALESCE(p_norma_tecnica, norma_tecnica),
        metodo_fabricacion        = COALESCE(p_metodo_fabricacion, metodo_fabricacion),
        fecha_analisis            = COALESCE(p_fecha_analisis, fecha_analisis),
        fecha_emision             = COALESCE(p_fecha_emision, fecha_emision),
        fecha_fabricacion         = COALESCE(p_fecha_fabricacion, fecha_fabricacion),
        fecha_vencimiento         = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tamano_lote_m3            = COALESCE(p_tamano_lote_m3, tamano_lote_m3),
        cantidad_envases          = COALESCE(p_cantidad_envases, cantidad_envases),
        valoracion_o2_pct         = COALESCE(p_valoracion_o2_pct, valoracion_o2_pct),
        limite_co2_ppm            = COALESCE(p_limite_co2_ppm, limite_co2_ppm),
        limite_co_ppm             = COALESCE(p_limite_co_ppm, limite_co_ppm),
        cilindro_muestreado_serie = COALESCE(NULLIF(TRIM(p_cilindro_muestreado_serie), ''), cilindro_muestreado_serie),
        temperatura_muestreo_c    = COALESCE(p_temperatura_muestreo_c, temperatura_muestreo_c),
        presion_muestreo_psi      = COALESCE(p_presion_muestreo_psi, presion_muestreo_psi),
        analista                  = COALESCE(p_analista, analista),
        conclusion                = COALESCE(p_conclusion, conclusion),
        codigo_documento          = COALESCE(p_codigo_documento, codigo_documento),
        version_documento         = COALESCE(p_version_documento, version_documento),
        id_archivo_pdf            = COALESCE(p_id_archivo_pdf, id_archivo_pdf),
        observacion               = COALESCE(p_observacion, observacion),
        id_usuario_modificacion   = p_id_usuario_auditoria,
        fecha_modificacion        = NOW()
    WHERE id = p_id;

    PERFORM bal_reemplazar_lote_protocolo_detalle(p_id, p_pruebas, p_envases, p_id_usuario_auditoria);

    RETURN bal_obtener_lote_protocolo(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_eliminar_lote_protocolo.sql
-- ============================================================

-- Function: bal_eliminar_lote_protocolo
-- Fase 5 — baja lógica de la ficha ICP. No se permite si alguna recarga ya la
-- referencia: el historial de un cilindro no puede quedar apuntando al vacío.
DROP FUNCTION IF EXISTS bal_eliminar_lote_protocolo(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_lote_protocolo(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_usos INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Ficha de lote y protocolo no encontrada');
    END IF;

    SELECT
        (SELECT COUNT(*) FROM bal_movimiento_recarga r WHERE r.id_lote_protocolo = p_id AND r.estado = 1)
      + (SELECT COUNT(*) FROM doc_salida d WHERE d.id_lote_protocolo = p_id AND d.estado = 1)
    INTO v_usos;

    IF v_usos > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', format('No se puede eliminar: %s recarga(s) referencian esta ficha', v_usos)
        );
    END IF;

    UPDATE bal_balon
    SET id_lote_protocolo_vigente = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo_vigente = p_id;

    UPDATE bal_lote_protocolo_envase
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo = p_id AND estado = 1;

    UPDATE bal_lote_protocolo_prueba
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo = p_id AND estado = 1;

    UPDATE bal_lote_protocolo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_aplicar_lote_protocolo_balones.sql
-- ============================================================

-- Function: bal_aplicar_lote_protocolo_balones
-- Fase 5 — marca una ficha ICP como la vigente de un conjunto de cilindros.
-- Es el punto de enganche del ingreso por compra (apunte 2.a.ii "al momento de
-- su ingreso") y del retorno de una recarga en planta externa.
--
-- p_id_balones NULL = aplicar a todos los cilindros que la propia relación de
-- envases aprobados ya emparejó por número de serie.
DROP FUNCTION IF EXISTS bal_aplicar_lote_protocolo_balones(p_id_lote_protocolo integer, p_id_balones json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_aplicar_lote_protocolo_balones(p_id_lote_protocolo integer, p_id_balones json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ids INTEGER[];
    v_aplicados INTEGER := 0;
    v_vinculados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id_lote_protocolo AND estado = 1) THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    IF p_id_balones IS NULL THEN
        SELECT ARRAY_AGG(DISTINCT e.id_balon)
        INTO v_ids
        FROM bal_lote_protocolo_envase e
        WHERE e.id_lote_protocolo = p_id_lote_protocolo
          AND e.estado = 1
          AND e.id_balon IS NOT NULL;
    ELSE
        SELECT ARRAY_AGG(DISTINCT (x#>>'{}')::INT)
        INTO v_ids
        FROM json_array_elements(p_id_balones) AS a(x)
        WHERE NULLIF(x#>>'{}', '') IS NOT NULL;
    END IF;

    v_ids := COALESCE(v_ids, ARRAY[]::INTEGER[]);

    IF array_length(v_ids, 1) IS NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object(
                'id_lote_protocolo', p_id_lote_protocolo,
                'balones_aplicados', 0,
                'envases_vinculados', 0
            )
        );
    END IF;

    -- Un cilindro que no estaba en la relación de envases pero sí se recargó
    -- con este lote entra a la relación: la ficha debe reflejar a qué envases
    -- se aplicó realmente. Sin número de serie se usa el código del cilindro.
    INSERT INTO bal_lote_protocolo_envase (
        id_lote_protocolo, serie_envase, id_balon,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    SELECT
        p_id_lote_protocolo,
        UPPER(TRIM(COALESCE(NULLIF(TRIM(b.numero_serie), ''), b.codigo_balon))),
        b.id,
        1, p_id_usuario_auditoria, p_id_usuario_auditoria
    FROM bal_balon b
    WHERE b.id = ANY(v_ids) AND b.estado = 1
    ON CONFLICT (id_lote_protocolo, serie_envase) DO UPDATE
    SET estado = 1,
        id_balon = EXCLUDED.id_balon,
        id_usuario_modificacion = EXCLUDED.id_usuario_modificacion,
        fecha_modificacion = NOW();

    GET DIAGNOSTICS v_vinculados = ROW_COUNT;

    UPDATE bal_balon
    SET id_lote_protocolo_vigente = p_id_lote_protocolo,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = ANY(v_ids) AND estado = 1;

    GET DIAGNOSTICS v_aplicados = ROW_COUNT;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id_lote_protocolo', p_id_lote_protocolo,
            'balones_aplicados', v_aplicados,
            'envases_vinculados', v_vinculados
        )
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_historial_lote_protocolo_balon.sql
-- ============================================================

-- Function: bal_historial_lote_protocolo_balon
-- Fase 5 — historial de fichas ICP por cilindro (apunte 2.a.ii).
--
-- El historial no se guarda aparte: se deriva de las recargas que referencian
-- una ficha. Hay dos orígenes porque la Fase 2 movió la recarga en planta
-- externa a doc_salida y la de mostrador siguió en bal_movimiento_recarga.
DROP FUNCTION IF EXISTS bal_historial_lote_protocolo_balon(p_id_balon integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION bal_historial_lote_protocolo_balon(p_id_balon integer, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_vigente JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object(
            'error', 'Cilindro no encontrado',
            'registros', '[]'::JSON,
            'total', 0,
            'vigente', NULL
        );
    END IF;

    WITH hist AS (
        SELECT
            'PLANTA_EXTERNA'::VARCHAR AS origen,
            d.id                      AS id_documento,
            d.numero                  AS numero_documento,
            COALESCE(d.fecha_llegada_almacen, d.fecha_retorno, d.fecha) AS fecha,
            d.id_lote_protocolo,
            d.id_almacen,
            d.id_proveedor
        FROM doc_salida d
        JOIN doc_salida_detalle dd ON dd.id_doc_salida = d.id AND dd.estado = 1
        WHERE d.estado = 1
          AND d.id_lote_protocolo IS NOT NULL
          AND dd.id_balon = p_id_balon
        UNION
        SELECT
            'MOVIMIENTO_RECARGA'::VARCHAR,
            r.id,
            NULL::VARCHAR,
            COALESCE(r.fecha_llegada_almacen, r.fecha_salida_almacen),
            r.id_lote_protocolo,
            r.id_almacen,
            r.id_proveedor
        FROM bal_movimiento_recarga r
        WHERE r.estado = 1
          AND r.id_lote_protocolo IS NOT NULL
          AND r.id_balon = p_id_balon
    ),
    pagina AS (
        SELECT
            h.origen,
            h.id_documento,
            h.numero_documento,
            h.fecha,
            h.id_lote_protocolo,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.valoracion_o2_pct,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            h.id_almacen,
            a.nombre AS nombre_almacen,
            h.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            (b.id_lote_protocolo_vigente = h.id_lote_protocolo) AS es_vigente
        FROM hist h
        JOIN bal_lote_protocolo lp ON lp.id = h.id_lote_protocolo
        JOIN bal_balon b ON b.id = p_id_balon
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        LEFT JOIN gen_almacen a ON a.id = h.id_almacen
        LEFT JOIN cli_clientes pv ON pv.id = h.id_proveedor
        ORDER BY h.fecha DESC NULLS LAST, h.id_documento DESC
        LIMIT GREATEST(COALESCE(p_limite, 50), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT
        COALESCE(
            json_agg(row_to_json(p) ORDER BY p.fecha DESC NULLS LAST, p.id_documento DESC),
            '[]'::JSON
        ),
        (SELECT COUNT(*) FROM hist)
    INTO v_registros, v_total
    FROM pagina p;

    SELECT row_to_json(v) INTO v_vigente
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.valoracion_o2_pct,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf
        FROM bal_balon b
        JOIN bal_lote_protocolo lp ON lp.id = b.id_lote_protocolo_vigente AND lp.estado = 1
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE b.id = p_id_balon
    ) v;

    RETURN json_build_object(
        'error', NULL,
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'vigente', v_vigente
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/movimientos-recarga/bal_crear_movimiento_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
-- p_id_lote_protocolo (Fase 5) va al final para no romper llamadas posicionales.
DROP FUNCTION IF EXISTS bal_crear_movimiento_recarga(p_fecha_salida_almacen date, p_id_balon integer, p_id_producto integer, p_capacidad numeric, p_id_unidad_medida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_serie_factura character varying, p_numero_factura character varying, p_id_comprobante integer, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_proveedor integer, p_observacion character varying, p_id_almacen integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_movimiento_recarga(p_fecha_salida_almacen date, p_id_balon integer, p_id_producto integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_serie_factura character varying DEFAULT NULL::character varying, p_numero_factura character varying DEFAULT NULL::character varying, p_id_comprobante integer DEFAULT NULL::integer, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_proveedor integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_lote_protocolo integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_tipo_recarga INTEGER;
    v_es_empresa BOOLEAN;
    v_capacidad_tipo NUMERIC;
    v_id_estado_recarga_externa INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_salida INTEGER;
    v_id_tipo_entrada INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_id_producto_gas_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_salida_almacen IS NULL THEN
        RETURN json_build_object('error', 'La fecha de salida de almacén es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Capacidad del tipo convertida a la unidad del producto-gas (canónica de pro_stock).
    SELECT
        COALESCE(prop.nombre, '') = 'EMPRESA',
        COALESCE(bal_capacidad_balon_en_unidad_gas(b.id), p_capacidad, 0)
    INTO v_es_empresa, v_capacidad_tipo
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    WHERE b.id = p_id_balon;

    IF NOT COALESCE(v_es_empresa, FALSE) THEN
        RETURN json_build_object(
            'error',
            'La recarga en planta externa solo aplica a balones de propiedad EMPRESA',
            'registro',
            NULL
        );
    END IF;

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_recarga_externa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_salida
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_recarga_externa IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado EN_RECARGA_EXTERNA del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_tipo_salida IS NULL OR v_id_tipo_entrada IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontraron los tipos SALIDA_PLANTA_EXTERNA / ENTRADA_PLANTA_EXTERNA. Revise el catálogo TipoMovBalon.',
            'registro',
            NULL
        );
    END IF;

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen, id_balon, id_tipo_recarga, id_producto, capacidad, id_unidad_medida,
        serie_guia_salida, numero_guia_salida, serie_guia_ingreso, numero_guia_ingreso,
        serie_factura, numero_factura, id_comprobante, id_comprobante_compra, fecha_llegada_almacen,
        lote, fecha_vencimiento_lote, fecha_prueba_hidrostatica, id_proveedor,
        id_lote_protocolo, observacion, id_almacen,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_fecha_salida_almacen, p_id_balon, v_id_tipo_recarga, p_id_producto, p_capacidad, p_id_unidad_medida,
        p_serie_guia_salida, p_numero_guia_salida, p_serie_guia_ingreso, p_numero_guia_ingreso,
        p_serie_factura, p_numero_factura, p_id_comprobante, p_id_comprobante_compra, p_fecha_llegada_almacen,
        p_lote, p_fecha_vencimiento_lote, p_fecha_prueba_hidrostatica, p_id_proveedor,
        p_id_lote_protocolo, p_observacion, p_id_almacen,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Fase 5: si la recarga trae ficha ICP, el cilindro queda con ella vigente.
    IF p_id_lote_protocolo IS NOT NULL AND p_id_balon IS NOT NULL THEN
        PERFORM bal_aplicar_lote_protocolo_balones(
            p_id_lote_protocolo,
            json_build_array(p_id_balon),
            p_id_usuario_auditoria
        );
    END IF;

    v_obs := COALESCE(NULLIF(TRIM(p_observacion), ''), 'Recarga planta externa');

    -- Libro de movimientos: salida a planta.
    v_mov := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'SALIDA_PLANTA_EXTERNA',
        p_fecha                     => p_fecha_salida_almacen::TIMESTAMP,
        p_id_producto               => NULL,
        p_id_balon                  => p_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_origen         => p_id_almacen,
        p_id_almacen_destino        => NULL,
        p_id_cliente                => p_id_proveedor,
        p_codigo_tipo_documento_origen => 'RECARGA',
        p_id_documento_origen       => v_id,
        p_glosa                     => v_obs,
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );
    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
    END IF;

    IF p_fecha_llegada_almacen IS NOT NULL THEN
        -- inv_registrar_movimiento ya actualizó id_estado_balon a DISPONIBLE.
        -- Solo fijamos id_producto_gas.
        UPDATE bal_balon
        SET
            id_producto_gas = COALESCE(p_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1
        RETURNING id_producto_gas INTO v_id_producto_gas_balon;

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
            p_fecha                     => p_fecha_llegada_almacen::TIMESTAMP,
            p_id_producto               => v_id_producto_gas_balon,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => COALESCE(p_capacidad, NULLIF(v_capacidad_tipo, 0), 1),
            p_id_almacen_origen         => NULL,
            p_id_almacen_destino        => p_id_almacen,
            p_id_cliente                => p_id_proveedor,
            p_codigo_tipo_documento_origen => 'RECARGA',
            p_id_documento_origen       => v_id,
            p_glosa                     => v_obs,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
        END IF;
    ELSE
        -- inv_registrar_movimiento (SALIDA_PLANTA_EXTERNA) ya puso EN_RECARGA_EXTERNA + limpió almacén.
        NULL;
    END IF;

    RETURN bal_obtener_movimiento_recarga(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/movimientos-recarga/bal_actualizar_movimiento_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
-- p_id_lote_protocolo (Fase 5) va al final para no romper llamadas posicionales.
DROP FUNCTION IF EXISTS bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date, p_id_producto integer, p_capacidad numeric, p_id_unidad_medida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_serie_factura character varying, p_numero_factura character varying, p_id_comprobante integer, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_proveedor integer, p_observacion character varying, p_id_almacen integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date DEFAULT NULL::date, p_id_producto integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_serie_factura character varying DEFAULT NULL::character varying, p_numero_factura character varying DEFAULT NULL::character varying, p_id_comprobante integer DEFAULT NULL::integer, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_proveedor integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_lote_protocolo integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada_antes DATE;
    v_fecha_llegada DATE;
    v_id_producto INTEGER;
    v_id_almacen INTEGER;
    v_id_proveedor INTEGER;
    v_capacidad_tipo NUMERIC;
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_id_compra INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_ya_tiene_entrada BOOLEAN;
    v_capacidad NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT fecha_llegada_almacen
    INTO v_fecha_llegada_antes
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE bal_movimiento_recarga
    SET
        fecha_salida_almacen = COALESCE(p_fecha_salida_almacen, fecha_salida_almacen),
        id_producto = COALESCE(p_id_producto, id_producto),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        serie_guia_salida = COALESCE(p_serie_guia_salida, serie_guia_salida),
        numero_guia_salida = COALESCE(p_numero_guia_salida, numero_guia_salida),
        serie_guia_ingreso = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
        serie_factura = COALESCE(p_serie_factura, serie_factura),
        numero_factura = COALESCE(p_numero_factura, numero_factura),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = CASE
            WHEN p_lote IS NOT NULL THEN NULLIF(TRIM(p_lote), '')
            ELSE lote
        END,
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_lote_protocolo = COALESCE(p_id_lote_protocolo, id_lote_protocolo),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        observacion = COALESCE(p_observacion, observacion),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
    RETURNING id_balon, fecha_llegada_almacen, id_producto, id_almacen, id_proveedor, observacion, capacidad
    INTO v_id_balon, v_fecha_llegada, v_id_producto, v_id_almacen, v_id_proveedor, v_obs, v_capacidad;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- Fase 5: si se corrige la ficha ICP, el cilindro pasa a tenerla vigente.
    IF p_id_lote_protocolo IS NOT NULL AND v_id_balon IS NOT NULL THEN
        PERFORM bal_aplicar_lote_protocolo_balones(
            p_id_lote_protocolo,
            json_build_array(v_id_balon),
            p_id_usuario_auditoria
        );
    END IF;

    IF v_fecha_llegada IS NOT NULL AND v_id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
                'registro',
                NULL
            );
        END IF;

        SELECT COALESCE(tb.capacidad, p_capacidad, 0)
        INTO v_capacidad_tipo
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE b.id = v_id_balon;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_en_almacen,
            id_almacen = COALESCE(v_id_almacen, id_almacen),
            id_producto_gas = COALESCE(v_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;

        -- Primera vez que se registra llegada: movimiento de entrada.
        -- Si ya hay compra vinculada, el documento de referencia es COMPRA (no GRE/RECARGA).
        IF v_fecha_llegada_antes IS NULL THEN
            SELECT COALESCE(p_id_comprobante_compra, id_comprobante_compra)
            INTO v_id_compra
            FROM bal_movimiento_recarga
            WHERE id = p_id;

            IF v_id_compra IS NOT NULL THEN
                v_id_documento_ref := v_id_compra;
            ELSE
                v_id_documento_ref := p_id;
            END IF;

            SELECT EXISTS (
                SELECT 1
                FROM inv_movimiento m
                INNER JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND m.id_balon = v_id_balon
                  AND tm.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND (
                    m.id_documento_origen = p_id
                    OR (v_id_compra IS NOT NULL AND m.id_documento_origen = v_id_compra)
                  )
            ) INTO v_ya_tiene_entrada;

            IF NOT COALESCE(v_ya_tiene_entrada, FALSE) THEN
                v_mov := inv_registrar_movimiento(
                    p_naturaleza                => 'BALON',
                    p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
                    p_fecha                     => v_fecha_llegada,
                    p_id_producto               => v_id_producto,
                    p_id_balon                  => v_id_balon,
                    p_cantidad                  => COALESCE(v_capacidad, 1),
                    p_id_almacen_destino        => v_id_almacen,
                    p_id_cliente                => v_id_proveedor,
                    p_codigo_tipo_documento_origen => CASE
                        WHEN v_id_compra IS NOT NULL THEN 'COMPRA'
                        ELSE 'RECARGA'
                    END,
                    p_id_documento_origen       => v_id_documento_ref,
                    p_glosa                     => COALESCE(
                        NULLIF(TRIM(v_obs), ''),
                        CASE
                            WHEN v_id_compra IS NOT NULL THEN 'Retorno planta externa (compra #' || v_id_compra || ')'
                            ELSE 'Retorno planta externa'
                        END
                    ),
                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
                END IF;
            END IF;
        ELSIF p_id_comprobante_compra IS NOT NULL THEN
            -- Compra vinculada después de la entrada: reapunta el kardex a COMPRA.
            v_mov := inv_repuntar_documento(
                p_codigo_tipo_documento_origen_actual => 'RECARGA',
                p_id_documento_origen_actual          => p_id,
                p_codigo_tipo_documento_origen_nuevo  => 'COMPRA',
                p_id_documento_origen_nuevo           => p_id_comprobante_compra,
                p_id_usuario_auditoria                => p_id_usuario_auditoria
            );
        END IF;
    END IF;

    -- Idempotente: solo inserta en bal_balon_ph_historial si hay P.H. y aún no hay fila para este movimiento.
    PERFORM bal_sync_ph_desde_recarga(p_id, p_id_usuario_auditoria);

    RETURN bal_obtener_movimiento_recarga(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/recargas-planta/bal_finalizar_recarga_planta.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
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
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_codigo_doc VARCHAR;
    v_det RECORD;
    v_mov JSON;
    v_id_balones INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM doc_salida WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    -- Datos del retorno sobre el propio documento.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        fecha_retorno = COALESCE(p_fecha_llegada_almacen, fecha_retorno),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
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

        -- Con factura vinculada el documento de referencia es la compra; si no, la orden.
        IF p_id_comprobante_compra IS NOT NULL THEN
            v_id_documento_ref := p_id_comprobante_compra;
            v_codigo_doc := 'COMPRA';
        ELSE
            v_id_documento_ref := p_id_recarga_planta;
            v_codigo_doc := 'ORDEN_SALIDA';
        END IF;

        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon,
                COALESCE(d.id_producto, b.id_producto_gas) AS id_producto,
                inv_convertir_a_unidad_producto(
                    COALESCE(d.id_producto, b.id_producto_gas),
                    d.cantidad,
                    d.id_unidad_medida
                ) AS cantidad
            FROM doc_salida_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
        LOOP
            v_id_balones := v_id_balones || v_det.id_balon;

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
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => COALESCE(v_det.cantidad, 1),
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => v_codigo_doc,
                p_id_documento_origen          => v_id_documento_ref,
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
    END IF;

    -- Fase 5: los cilindros que volvieron quedan con esta ficha como vigente.
    IF p_id_lote_protocolo IS NOT NULL AND array_length(v_id_balones, 1) IS NOT NULL THEN
        PERFORM bal_aplicar_lote_protocolo_balones(
            p_id_lote_protocolo,
            array_to_json(v_id_balones),
            p_id_usuario_auditoria
        );
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta
    ));
END;
$function$;


-- ============================================================
-- database_sql/funciones/balones/bal_obtener_balon.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_balon
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.948Z
DROP FUNCTION IF EXISTS bal_obtener_balon(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_balon(p_id integer)
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
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            cu.razon_social AS nombre_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            cp.razon_social AS nombre_cliente_propietario,
            b.id_referencia,
            ref.nombre AS nombre_referencia,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_planta,
            COALESCE(pl.razon_social, TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno))) AS nombre_planta,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            tb.capacidad_lb,
            tb.peso AS peso_tipo_balon,
            b.peso_aproximado_kg,
            COALESCE(b.peso_aproximado_kg, tb.peso) AS peso_guia_kg,
            b.sello_inspeccion,
            um.nombre AS nombre_unidad_medida,
            tb.vigencia_ph_anios AS vigencia_ph_tipo_anios,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            -- Fase 5: ficha ICP vigente del cilindro (oxígeno medicinal).
            b.id_lote_protocolo_vigente,
            lp.numero_lote AS numero_lote_vigente,
            lp.numero_protocolo AS numero_protocolo_vigente,
            lp.fecha_vencimiento AS fecha_vencimiento_lote_vigente,
            (
                lp.fecha_vencimiento IS NOT NULL
                AND lp.fecha_vencimiento < CURRENT_DATE
            ) AS lote_vigente_vencido,
            b.fecha_ultima_prueba_hidrostatica,
            b.vigencia_prueba_hidrostatica_anios,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.fecha_fabricacion,
            b.anio_fabricacion,
            b.mes_fabricacion,
            b.numero_recepcion,
            b.presion_actual,
            b.observacion,
            b.tipo_valvula,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion,
            b.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            b.id_usuario_modificacion,
            umu.nombre AS nombre_usuario_modificacion,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            (
                SELECT row_to_json(bj)
                FROM (
                    SELECT
                        bb.id,
                        bb.id_motivo_baja,
                        mb.nombre AS nombre_motivo_baja,
                        bb.fecha_baja,
                        bb.motivo_detalle,
                        bb.id_cliente_comprador,
                        cc.razon_social AS nombre_cliente_comprador,
                        bb.serie_comprobante,
                        bb.numero_comprobante,
                        bb.monto_venta,
                        bb.observacion,
                        bb.id_usuario_solicita,
                        us.nombre AS nombre_usuario_solicita,
                        bb.id_usuario_autoriza,
                        ua.nombre AS nombre_usuario_autoriza,
                        bb.fecha_autorizacion,
                        bb.estado_aprobacion
                    FROM bal_baja_balon bb
                    LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
                    LEFT JOIN cli_clientes cc ON bb.id_cliente_comprador = cc.id
                    LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
                    LEFT JOIN auth_usuarios ua ON bb.id_usuario_autoriza = ua.id
                    WHERE bb.id_balon = b.id AND bb.estado = 1 AND bb.estado_aprobacion = 'APROBADA'
                    ORDER BY bb.fecha_autorizacion DESC NULLS LAST, bb.id DESC
                    LIMIT 1
                ) bj
            ) AS baja
        FROM bal_balon b
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones ref ON b.id_referencia = ref.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN cli_clientes pl ON b.id_planta = pl.id
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN bal_lote_protocolo lp ON lp.id = b.id_lote_protocolo_vigente AND lp.estado = 1
        LEFT JOIN auth_usuarios uc ON b.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umu ON b.id_usuario_modificacion = umu.id
        WHERE b.id = p_id AND b.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
