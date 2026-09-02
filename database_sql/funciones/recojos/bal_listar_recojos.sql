-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_recojos
-- Overloads: 2
-- Generated: 2026-09-02T21:31:03.575Z
DROP FUNCTION IF EXISTS bal_listar_recojos(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_id_prestamo integer, p_id_alquiler integer, p_estado_nombre character varying, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_recojos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_estado_nombre character varying DEFAULT NULL::character varying, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_estado_nombre := NULLIF(UPPER(TRIM(p_estado_nombre)), '');

    SELECT COUNT(*)
    INTO v_total
    FROM bal_recojo r
    LEFT JOIN cli_clientes c ON c.id = r.id_cliente
    LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
    LEFT JOIN bal_alquiler al ON al.id = r.id_alquiler
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
      AND (p_id_alquiler IS NULL OR r.id_alquiler = p_id_alquiler)
      AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
      AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            dir.latitud,
            dir.longitud,
            dir.direccion,
            r.id_prestamo,
            pr.numero_prestamo,
            r.id_alquiler,
            al.numero_alquiler,
            CASE
                WHEN r.id_prestamo IS NOT NULL AND r.id_alquiler IS NOT NULL THEN 'MIXTO'
                WHEN r.id_alquiler IS NOT NULL THEN 'ALQUILER'
                ELSE 'PRESTAMO'
            END AS tipo_origen,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_recojo_detalle rd
                WHERE rd.id_recojo = r.id AND rd.estado = 1
            ) AS total_detalles,
            CASE
                WHEN r.id_alquiler IS NOT NULL
                     AND COALESCE(al.id_producto_regulador, al.id_producto_stock) IS NOT NULL
                THEN TRUE
                ELSE FALSE
            END AS tiene_regulador,
            CASE
                WHEN r.id_alquiler IS NOT NULL
                     AND COALESCE(al.id_producto_regulador, al.id_producto_stock) IS NOT NULL
                     AND NOT EXISTS (
                         SELECT 1
                         FROM bal_recojo_detalle rd0
                         WHERE rd0.id_recojo = r.id AND rd0.estado = 1
                     )
                THEN TRUE
                ELSE FALSE
            END AS es_solo_regulador,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN bal_alquiler al ON al.id = r.id_alquiler
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud, cd.direccion
            FROM cli_direcciones cd
            WHERE cd.id_cliente = r.id_cliente
              AND cd.es_principal = TRUE
              AND cd.estado = 1
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        WHERE r.estado = 1
          AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
          AND (p_id_alquiler IS NULL OR r.id_alquiler = p_id_alquiler)
          AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
          AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
          )
        ORDER BY r.fecha_programada DESC NULLS LAST, r.id DESC
        LIMIT p_limite
        OFFSET COALESCE(p_offset, 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$

DROP FUNCTION IF EXISTS bal_listar_recojos(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_id_prestamo integer, p_estado_nombre character varying, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_recojos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_prestamo integer DEFAULT NULL::integer, p_estado_nombre character varying DEFAULT NULL::character varying, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_estado_nombre := NULLIF(UPPER(TRIM(p_estado_nombre)), '');

    SELECT COUNT(*)
    INTO v_total
    FROM bal_recojo r
    LEFT JOIN cli_clientes c ON c.id = r.id_cliente
    LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
      AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
      AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            r.id_prestamo,
            pr.numero_prestamo,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_recojo_detalle rd
                WHERE rd.id_recojo = r.id AND rd.estado = 1
            ) AS total_detalles,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        WHERE r.estado = 1
          AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
          AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
          AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
          )
        ORDER BY r.fecha_programada DESC NULLS LAST, r.id DESC
        LIMIT p_limite
        OFFSET COALESCE(p_offset, 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
