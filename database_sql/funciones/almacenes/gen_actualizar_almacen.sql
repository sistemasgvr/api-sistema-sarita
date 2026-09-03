-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_almacen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.960Z
DROP FUNCTION IF EXISTS gen_actualizar_almacen(p_id integer, p_id_sucursal integer, p_nombre character varying, p_ubicacion character varying, p_descripcion character varying, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_almacen(p_id integer, p_id_sucursal integer DEFAULT NULL::integer, p_nombre character varying DEFAULT NULL::character varying, p_ubicacion character varying DEFAULT NULL::character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_almacen
    SET
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        nombre = COALESCE(p_nombre, nombre),
        ubicacion = COALESCE(p_ubicacion, ubicacion),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_almacen(p_id);
END;
$function$;
