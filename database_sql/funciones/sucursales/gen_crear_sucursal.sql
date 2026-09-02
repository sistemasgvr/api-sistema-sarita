-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_sucursal
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.711Z
DROP FUNCTION IF EXISTS gen_crear_sucursal(p_codigo character varying, p_nombre character varying, p_direccion character varying, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_telefono character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_sucursal(p_codigo character varying, p_nombre character varying, p_direccion character varying DEFAULT NULL::character varying, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_telefono character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_sucursal (
        codigo,
        nombre,
        direccion,
        id_departamento,
        id_provincia,
        id_distrito,
        telefono,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_direccion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_telefono,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_sucursal(v_id);
END;
$function$
