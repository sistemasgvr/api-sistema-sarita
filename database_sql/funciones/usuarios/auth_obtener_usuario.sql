-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: auth_obtener_usuario
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.507Z
DROP FUNCTION IF EXISTS auth_obtener_usuario(p_id integer);

CREATE OR REPLACE FUNCTION auth_obtener_usuario(p_id integer)
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
            u.id,
            u.nombre,
            u.correo,
            u.estado,
            u.id_trabajador,
            u.fecha_creacion,
            u.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'nombre', r.nombre,
                    'descripcion', r.descripcion
                )), '[]'::JSON)
                FROM auth_usuarios_roles ur
                INNER JOIN auth_roles r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = TRUE AND r.estado = TRUE
            ) AS roles
        FROM auth_usuarios u
        WHERE u.id = p_id AND u.estado = TRUE
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
