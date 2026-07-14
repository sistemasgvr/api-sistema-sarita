CREATE OR REPLACE FUNCTION bal_crear_movimiento(
    p_id_balon INTEGER,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen_origen INTEGER DEFAULT NULL,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_fecha_movimiento TIMESTAMP DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_tipo_movimiento IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de movimiento indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_movimiento (
        id_balon, id_tipo_movimiento, id_documento_ref, id_tipo_documento_ref,
        id_cliente, id_almacen_origen, id_almacen_destino,
        fecha_movimiento, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_tipo_movimiento, p_id_documento_ref, p_id_tipo_documento_ref,
        p_id_cliente, p_id_almacen_origen, p_id_almacen_destino,
        COALESCE(p_fecha_movimiento, NOW()), p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_movimiento(v_id);
END;
$function$;
