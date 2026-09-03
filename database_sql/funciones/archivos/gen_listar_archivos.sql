-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_archivos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.962Z
DROP FUNCTION IF EXISTS gen_listar_archivos(p_busqueda character varying, p_id_empresa integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION gen_listar_archivos(p_busqueda character varying DEFAULT ''::character varying, p_id_empresa integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_archivo a
    WHERE a.estado = 1
      AND (p_id_empresa IS NULL OR a.id_empresa = p_id_empresa)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(a.nombre_original, p_busqueda)
          OR gen_texto_coincide(a.ruta, p_busqueda)
          OR gen_texto_coincide(COALESCE(a.mime_type, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            a.id,
            a.nombre_original,
            a.nombre_almacenado,
            a.ruta,
            a.bucket,
            a.mime_type,
            a.extension,
            a.tamanio_bytes,
            a.id_empresa,
            e.nombre_comercial AS nombre_empresa,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_archivo a
        LEFT JOIN gen_empresa e ON a.id_empresa = e.id
        LEFT JOIN auth_usuarios uc ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON a.id_usuario_modificacion = um.id
        WHERE a.estado = 1
          AND (p_id_empresa IS NULL OR a.id_empresa = p_id_empresa)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(a.nombre_original, p_busqueda)
              OR gen_texto_coincide(a.ruta, p_busqueda)
              OR gen_texto_coincide(COALESCE(a.mime_type, ''), p_busqueda)
          )
        ORDER BY a.fecha_creacion DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
