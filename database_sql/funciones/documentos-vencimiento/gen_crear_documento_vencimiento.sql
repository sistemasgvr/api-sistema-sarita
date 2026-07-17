DROP FUNCTION IF EXISTS gen_crear_documento_vencimiento(INTEGER, VARCHAR, INTEGER, DATE, DATE, VARCHAR, VARCHAR, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_crear_documento_vencimiento(
    p_id_categoria INTEGER DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_fecha_renovacion DATE DEFAULT NULL,
    p_numero_documento VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_documento_vencimiento (
        id_categoria,
        descripcion,
        id_vehiculo,
        fecha_vencimiento,
        fecha_renovacion,
        numero_documento,
        observacion,
        id_estado,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_categoria,
        p_descripcion,
        p_id_vehiculo,
        p_fecha_vencimiento,
        p_fecha_renovacion,
        p_numero_documento,
        p_observacion,
        p_id_estado,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_documento_vencimiento(v_id);
END;
$function$;
