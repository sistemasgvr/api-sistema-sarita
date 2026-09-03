-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_sucursal
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_actualizar_sucursal(p_id integer, p_codigo character varying, p_nombre character varying, p_direccion character varying, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_telefono character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_sucursal(p_id integer, p_codigo character varying DEFAULT NULL::character varying, p_nombre character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_telefono character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_sucursal
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        direccion = COALESCE(p_direccion, direccion),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_sucursal(p_id);
END;
$function$;
