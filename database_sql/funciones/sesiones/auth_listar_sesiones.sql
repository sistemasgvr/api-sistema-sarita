CREATE OR REPLACE FUNCTION auth_listar_sesiones(
    p_id_usuario INTEGER DEFAULT NULL,
    p_solo_activas BOOLEAN DEFAULT TRUE,
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
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
$function$;
