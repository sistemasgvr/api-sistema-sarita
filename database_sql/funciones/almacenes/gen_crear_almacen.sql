-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_almacen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_almacen(p_id_sucursal integer, p_nombre character varying, p_ubicacion character varying, p_descripcion character varying, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_almacen(p_id_sucursal integer, p_nombre character varying, p_ubicacion character varying DEFAULT NULL::character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_almacen (
        id_sucursal,
        nombre,
        ubicacion,
        descripcion,
        id_departamento,
        id_provincia,
        id_distrito,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal,
        p_nombre,
        p_ubicacion,
        p_descripcion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_almacen(v_id);
END;
$function$;
