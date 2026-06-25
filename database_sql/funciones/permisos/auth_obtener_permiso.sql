CREATE OR REPLACE FUNCTION auth_obtener_permiso(p_id INTEGER)
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
            p.id,
            p.nombre,
            p.descripcion,
            p.estado,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM auth_permisos p
        LEFT JOIN auth_usuarios uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON p.id_usuario_modificacion = um.id
        WHERE p.id = p_id AND p.estado = TRUE
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
