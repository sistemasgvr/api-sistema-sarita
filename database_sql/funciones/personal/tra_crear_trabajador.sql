-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: tra_crear_trabajador
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.796Z
DROP FUNCTION IF EXISTS tra_crear_trabajador(p_nombres character varying, p_apellido_paterno character varying, p_apellido_materno character varying, p_id_tipo_documento integer, p_numero_documento character varying, p_direccion character varying, p_referencia character varying, p_latitud numeric, p_longitud numeric, p_id_pais integer, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_fecha_nacimiento date, p_fecha_inicio date, p_fecha_cese date, p_id_area integer, p_id_cargo integer, p_id_usuario_auditoria integer, p_correo character varying);

CREATE OR REPLACE FUNCTION tra_crear_trabajador(p_nombres character varying, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_id_tipo_documento integer DEFAULT NULL::integer, p_numero_documento character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_referencia character varying DEFAULT NULL::character varying, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric, p_id_pais integer DEFAULT NULL::integer, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_fecha_nacimiento date DEFAULT NULL::date, p_fecha_inicio date DEFAULT NULL::date, p_fecha_cese date DEFAULT NULL::date, p_id_area integer DEFAULT NULL::integer, p_id_cargo integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_correo character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_trabajador INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE numero_documento = p_numero_documento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe un trabajador registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO tra_trabajadores (
            nombres, apellido_paterno, apellido_materno,
        id_tipo_documento, numero_documento, correo,
        direccion, referencia, latitud, longitud,
            id_pais, id_departamento, id_provincia, id_distrito,
            fecha_nacimiento, fecha_inicio, fecha_cese,
            id_area, id_cargo,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_nombres, p_apellido_paterno, p_apellido_materno,
        p_id_tipo_documento, p_numero_documento, p_correo,
        p_direccion, p_referencia, p_latitud, p_longitud,
            p_id_pais, p_id_departamento, p_id_provincia, p_id_distrito,
            p_fecha_nacimiento, p_fecha_inicio, p_fecha_cese,
            p_id_area, p_id_cargo,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_trabajador;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo o ubicación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(v_id_trabajador);
END;
$function$
