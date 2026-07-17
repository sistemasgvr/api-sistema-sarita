DROP FUNCTION IF EXISTS gen_actualizar_documento_vencimiento(INTEGER, INTEGER, VARCHAR, INTEGER, DATE, DATE, VARCHAR, VARCHAR, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_documento_vencimiento(
    p_id INTEGER,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_documento_vencimiento
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_vehiculo = COALESCE(p_id_vehiculo, id_vehiculo),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        fecha_renovacion = COALESCE(p_fecha_renovacion, fecha_renovacion),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        observacion = COALESCE(p_observacion, observacion),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_documento_vencimiento(p_id);
END;
$function$;
