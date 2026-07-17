CREATE OR REPLACE FUNCTION bal_actualizar_movimiento(
    p_id INTEGER,
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
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE bal_movimiento
    SET
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_documento_ref = COALESCE(p_id_documento_ref, id_documento_ref),
        id_tipo_documento_ref = COALESCE(p_id_tipo_documento_ref, id_tipo_documento_ref),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_almacen_origen = COALESCE(p_id_almacen_origen, id_almacen_origen),
        id_almacen_destino = COALESCE(p_id_almacen_destino, id_almacen_destino),
        fecha_movimiento = COALESCE(p_fecha_movimiento, fecha_movimiento),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_movimiento(p_id);
END;
$function$;
