-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_empresa
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.697Z
DROP FUNCTION IF EXISTS gen_actualizar_empresa(p_id integer, p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_empresa(p_id integer, p_ruc character varying DEFAULT NULL::character varying, p_razon_social character varying DEFAULT NULL::character varying, p_nombre_comercial character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric, p_psi_minimo_util numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_tolerancia_m3_ruta_pueblo IS NOT NULL AND p_tolerancia_m3_ruta_pueblo < 0 THEN
        RETURN json_build_object('error', 'La tolerancia de ruta pueblos no puede ser negativa', 'registro', NULL);
    END IF;

    IF p_psi_minimo_util IS NOT NULL AND p_psi_minimo_util < 0 THEN
        RETURN json_build_object('error', 'El umbral PSI mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    UPDATE gen_empresa
    SET
        ruc = COALESCE(p_ruc, ruc),
        razon_social = COALESCE(p_razon_social, razon_social),
        nombre_comercial = COALESCE(p_nombre_comercial, nombre_comercial),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        tolerancia_m3_ruta_pueblo = COALESCE(p_tolerancia_m3_ruta_pueblo, tolerancia_m3_ruta_pueblo),
        psi_minimo_util = COALESCE(p_psi_minimo_util, psi_minimo_util),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id);
END;
$function$
