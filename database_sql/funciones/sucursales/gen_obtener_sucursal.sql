CREATE OR REPLACE FUNCTION gen_obtener_sucursal(p_id INTEGER)
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
            s.codigo,
            s.nombre,
            s.direccion,
            s.id_departamento,
            s.id_provincia,
            s.id_distrito,
            s.telefono,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_sucursal s
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON s.id_usuario_modificacion = um.id
        WHERE s.id = p_id AND s.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
