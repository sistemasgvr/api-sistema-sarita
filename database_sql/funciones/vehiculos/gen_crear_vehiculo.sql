-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_vehiculo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.712Z
DROP FUNCTION IF EXISTS gen_crear_vehiculo(p_placa character varying, p_id_cliente integer, p_id_tipo_vehiculo integer, p_placa2 character varying, p_marca character varying, p_marca2 character varying, p_modelo character varying, p_anio integer, p_color character varying, p_certificado_inscripcion character varying, p_certificado2 character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_vehiculo(p_placa character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_tipo_vehiculo integer DEFAULT NULL::integer, p_placa2 character varying DEFAULT NULL::character varying, p_marca character varying DEFAULT NULL::character varying, p_marca2 character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_anio integer DEFAULT NULL::integer, p_color character varying DEFAULT NULL::character varying, p_certificado_inscripcion character varying DEFAULT NULL::character varying, p_certificado2 character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM gen_vehiculo WHERE placa = p_placa AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'Ya existe un vehículo activo con esa placa');
    END IF;

    INSERT INTO gen_vehiculo (
        id_cliente,
        id_tipo_vehiculo,
        placa,
        placa2,
        marca,
        marca2,
        modelo,
        anio,
        color,
        certificado_inscripcion,
        certificado2,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_tipo_vehiculo,
        p_placa,
        p_placa2,
        p_marca,
        p_marca2,
        p_modelo,
        p_anio,
        p_color,
        p_certificado_inscripcion,
        p_certificado2,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_vehiculo(v_id);
END;
$function$
