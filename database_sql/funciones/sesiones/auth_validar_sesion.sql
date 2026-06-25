CREATE OR REPLACE FUNCTION auth_validar_sesion(p_token VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.id_usuario,
            u.nombre AS nombre_usuario,
            u.correo,
            s.fecha_inicio
        FROM auth_sesiones s
        INNER JOIN auth_usuarios u ON s.id_usuario = u.id
        WHERE s.token = p_token
          AND s.estado = TRUE
          AND s.fecha_fin IS NULL
          AND u.estado = TRUE
    ) t;

    RETURN json_build_object('valida', v_registro IS NOT NULL, 'registro', v_registro);
END;
$function$;
