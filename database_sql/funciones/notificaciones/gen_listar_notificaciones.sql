-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_notificaciones
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.962Z
DROP FUNCTION IF EXISTS gen_listar_notificaciones(p_id_usuario integer, p_solo_no_leidas integer, p_buscar character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION gen_listar_notificaciones(p_id_usuario integer, p_solo_no_leidas integer DEFAULT 0, p_buscar character varying DEFAULT ''::character varying, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total INTEGER;
    v_registros JSON;
    v_buscar VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario IS NULL THEN
        RETURN json_build_object('error', 'El usuario es obligatorio', 'registros', '[]'::JSON, 'total', 0);
    END IF;

    v_buscar := LOWER(TRIM(COALESCE(p_buscar, '')));

    SELECT COUNT(*)::INTEGER
    INTO v_total
    FROM gen_notificacion n
    WHERE n.id_usuario = p_id_usuario
      AND n.estado = 1
      AND (COALESCE(p_solo_no_leidas, 0) = 0 OR n.leida = FALSE)
      AND (
          v_buscar = ''
          OR LOWER(n.titulo) LIKE '%' || v_buscar || '%'
          OR LOWER(COALESCE(n.mensaje, '')) LIKE '%' || v_buscar || '%'
          OR LOWER(n.codigo_tipo) LIKE '%' || v_buscar || '%'
      );

    SELECT COALESCE(json_agg(t.row_data), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', n.id,
            'id_usuario', n.id_usuario,
            'codigo_tipo', n.codigo_tipo,
            'titulo', n.titulo,
            'mensaje', n.mensaje,
            'payload', n.payload,
            'id_referencia', n.id_referencia,
            'tipo_referencia', n.tipo_referencia,
            'clave_dedupe', n.clave_dedupe,
            'leida', n.leida,
            'fecha_lectura', n.fecha_lectura,
            'fecha_creacion', n.fecha_creacion,
            'fecha_modificacion', n.fecha_modificacion
        ) AS row_data
        FROM gen_notificacion n
        WHERE n.id_usuario = p_id_usuario
          AND n.estado = 1
          AND (COALESCE(p_solo_no_leidas, 0) = 0 OR n.leida = FALSE)
          AND (
              v_buscar = ''
              OR LOWER(n.titulo) LIKE '%' || v_buscar || '%'
              OR LOWER(COALESCE(n.mensaje, '')) LIKE '%' || v_buscar || '%'
              OR LOWER(n.codigo_tipo) LIKE '%' || v_buscar || '%'
          )
        ORDER BY n.leida ASC, n.fecha_creacion DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
