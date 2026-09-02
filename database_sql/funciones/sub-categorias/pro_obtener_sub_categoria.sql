-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_obtener_sub_categoria
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.791Z
DROP FUNCTION IF EXISTS pro_obtener_sub_categoria(p_id integer);

CREATE OR REPLACE FUNCTION pro_obtener_sub_categoria(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            sc.id,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            sc.nombre,
            sc.descripcion,
            sc.estado,
            sc.fecha_creacion,
            sc.fecha_modificacion,
            sc.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            sc.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM pro_producto p
                WHERE p.id_sub_categoria = sc.id AND p.estado = 1
            ) AS total_productos,
            (
                SELECT COALESCE(json_agg(p.nombre ORDER BY p.nombre ASC), '[]'::JSON)
                FROM pro_producto p
                WHERE p.id_sub_categoria = sc.id AND p.estado = 1
            ) AS nombres_productos
        FROM pro_sub_categoria sc
        INNER JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN auth_usuarios uc ON sc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON sc.id_usuario_modificacion = um.id
        WHERE sc.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
