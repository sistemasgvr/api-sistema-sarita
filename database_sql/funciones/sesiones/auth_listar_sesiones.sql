-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_listar_sesiones
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.500Z
DROP FUNCTION IF EXISTS auth_listar_sesiones(p_id_usuario integer, p_solo_activas boolean, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION auth_listar_sesiones(p_id_usuario integer DEFAULT NULL::integer, p_solo_activas boolean DEFAULT true, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM auth_sesiones s
    INNER JOIN auth_usuarios u ON s.id_usuario = u.id
    WHERE (p_id_usuario IS NULL OR s.id_usuario = p_id_usuario)
      AND (NOT p_solo_activas OR (s.estado = TRUE AND s.fecha_fin IS NULL));

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.id_usuario,
            u.nombre AS nombre_usuario,
            u.correo,
            s.ip,
            s.user_agent,
            s.fecha_inicio,
            s.fecha_fin,
            s.estado,
            s.fecha_creacion
        FROM auth_sesiones s
        INNER JOIN auth_usuarios u ON s.id_usuario = u.id
        WHERE (p_id_usuario IS NULL OR s.id_usuario = p_id_usuario)
          AND (NOT p_solo_activas OR (s.estado = TRUE AND s.fecha_fin IS NULL))
        ORDER BY s.fecha_inicio DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
