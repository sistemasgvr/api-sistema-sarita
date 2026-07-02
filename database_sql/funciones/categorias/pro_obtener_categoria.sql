CREATE OR REPLACE FUNCTION pro_obtener_categoria(p_id INTEGER)
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
            c.id,
            c.nombre,
            c.descripcion,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM pro_sub_categoria sc
                WHERE sc.id_categoria = c.id AND sc.estado = 1
            ) AS total_sub_categorias
        FROM pro_categoria c
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
