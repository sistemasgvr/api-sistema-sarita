DROP FUNCTION IF EXISTS gen_actualizar_vehiculo(INTEGER, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER);
CREATE OR REPLACE FUNCTION gen_actualizar_vehiculo(
    p_id INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_tipo_vehiculo INTEGER DEFAULT NULL,
    p_placa VARCHAR DEFAULT NULL,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_placa IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_vehiculo
        WHERE placa = p_placa AND estado = 1 AND id <> p_id
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'Ya existe un vehículo activo con esa placa');
    END IF;

    UPDATE gen_vehiculo
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_tipo_vehiculo = COALESCE(p_id_tipo_vehiculo, id_tipo_vehiculo),
        placa = COALESCE(p_placa, placa),
        placa2 = COALESCE(p_placa2, placa2),
        marca = COALESCE(p_marca, marca),
        marca2 = COALESCE(p_marca2, marca2),
        modelo = COALESCE(p_modelo, modelo),
        anio = COALESCE(p_anio, anio),
        color = COALESCE(p_color, color),
        certificado_inscripcion = COALESCE(p_certificado_inscripcion, certificado_inscripcion),
        certificado2 = COALESCE(p_certificado2, certificado2),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_vehiculo(p_id);
END;
$function$;