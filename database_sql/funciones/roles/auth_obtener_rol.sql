CREATE OR REPLACE FUNCTION auth_obtener_rol(p_id INTEGER)
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
            r.id,
            r.nombre,
            r.descripcion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            r.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', p.id,
                    'nombre', p.nombre,
                    'descripcion', p.descripcion
                )), '[]'::JSON)
                FROM auth_roles_permisos rp
                INNER JOIN auth_permisos p ON rp.id_permiso = p.id
                WHERE rp.id_rol = r.id AND rp.estado = TRUE AND p.estado = TRUE
            ) AS permisos
        FROM auth_roles r
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON r.id_usuario_modificacion = um.id
        WHERE r.id = p_id AND r.estado = TRUE
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
