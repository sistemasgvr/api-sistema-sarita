-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: tra_actualizar_trabajador
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.796Z
DROP FUNCTION IF EXISTS tra_actualizar_trabajador(p_id integer, p_nombres character varying, p_apellido_paterno character varying, p_apellido_materno character varying, p_id_tipo_documento integer, p_numero_documento character varying, p_direccion character varying, p_referencia character varying, p_latitud numeric, p_longitud numeric, p_id_pais integer, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_fecha_nacimiento date, p_fecha_inicio date, p_fecha_cese date, p_id_area integer, p_id_cargo integer, p_id_usuario_auditoria integer, p_correo character varying);

CREATE OR REPLACE FUNCTION tra_actualizar_trabajador(p_id integer, p_nombres character varying DEFAULT NULL::character varying, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_id_tipo_documento integer DEFAULT NULL::integer, p_numero_documento character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_referencia character varying DEFAULT NULL::character varying, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric, p_id_pais integer DEFAULT NULL::integer, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_fecha_nacimiento date DEFAULT NULL::date, p_fecha_inicio date DEFAULT NULL::date, p_fecha_cese date DEFAULT NULL::date, p_id_area integer DEFAULT NULL::integer, p_id_cargo integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_correo character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_existe INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_existe FROM tra_trabajadores WHERE id = p_id AND estado IN (0, 1);
    IF v_existe = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un trabajador con id ' || p_id);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM tra_trabajadores
        WHERE numero_documento = p_numero_documento AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro trabajador registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        UPDATE tra_trabajadores
        SET
            nombres               = COALESCE(p_nombres, nombres),
            apellido_paterno      = COALESCE(p_apellido_paterno, apellido_paterno),
            apellido_materno      = COALESCE(p_apellido_materno, apellido_materno),
            id_tipo_documento     = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento          = COALESCE(p_numero_documento, numero_documento),
        correo                    = COALESCE(p_correo, correo),
            direccion             = COALESCE(p_direccion, direccion),
            referencia            = COALESCE(p_referencia, referencia),
            latitud               = COALESCE(p_latitud, latitud),
            longitud              = COALESCE(p_longitud, longitud),
            id_pais               = COALESCE(p_id_pais, id_pais),
            id_departamento       = COALESCE(p_id_departamento, id_departamento),
            id_provincia          = COALESCE(p_id_provincia, id_provincia),
            id_distrito           = COALESCE(p_id_distrito, id_distrito),
            fecha_nacimiento      = COALESCE(p_fecha_nacimiento, fecha_nacimiento),
            fecha_inicio          = COALESCE(p_fecha_inicio, fecha_inicio),
            fecha_cese            = COALESCE(p_fecha_cese, fecha_cese),
            id_area               = COALESCE(p_id_area, id_area),
            id_cargo              = COALESCE(p_id_cargo, id_cargo),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion    = NOW()
        WHERE id = p_id AND estado IN (0, 1);

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo o ubicación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(p_id);
END;
$function$
