-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_almacen
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.742Z
DROP FUNCTION IF EXISTS gen_obtener_almacen(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_almacen(p_id integer)
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
            a.id,
            a.id_sucursal,
            s.nombre AS nombre_sucursal,
            a.nombre,
            a.ubicacion,
            a.descripcion,
            a.id_departamento,
            a.id_provincia,
            a.id_distrito,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_almacen a
        INNER JOIN gen_sucursal s ON a.id_sucursal = s.id
        LEFT JOIN auth_usuarios uc ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON a.id_usuario_modificacion = um.id
        WHERE a.id = p_id AND a.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
