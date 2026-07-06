DROP FUNCTION IF EXISTS gen_crear_vehiculo(VARCHAR, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION gen_crear_vehiculo(
    p_placa VARCHAR,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_tipo_vehiculo INTEGER DEFAULT NULL,
    p_placa2 VARCHAR DEFAULT NULL,
    p_marca VARCHAR DEFAULT NULL,
    p_marca2 VARCHAR DEFAULT NULL,
    p_modelo VARCHAR DEFAULT NULL,
    p_anio INTEGER DEFAULT NULL,
    p_color VARCHAR DEFAULT NULL,
    p_certificado_inscripcion VARCHAR DEFAULT NULL,
    p_certificado2 VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
$function$;