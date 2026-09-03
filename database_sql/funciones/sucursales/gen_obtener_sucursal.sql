-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_sucursal
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS gen_obtener_sucursal(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_sucursal(p_id integer)
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
            s.id,
            s.codigo,
            s.nombre,
            s.direccion,
            s.id_departamento,
            dep.nombre AS nombre_departamento,
            s.id_provincia,
            prov.nombre AS nombre_provincia,
            s.id_distrito,
            dist.nombre AS nombre_distrito,
            s.telefono,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_sucursal s
        LEFT JOIN gen_departamento dep ON dep.id = s.id_departamento
        LEFT JOIN gen_provincia prov ON prov.id = s.id_provincia
        LEFT JOIN gen_distrito dist ON dist.id = s.id_distrito
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON s.id_usuario_modificacion = um.id
        WHERE s.id = p_id AND s.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
