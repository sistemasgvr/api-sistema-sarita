CREATE OR REPLACE FUNCTION bal_actualizar_mantenimiento(
    p_id INTEGER,
    p_id_tipo_mantenimiento INTEGER DEFAULT NULL,
    p_fecha_ingreso DATE DEFAULT NULL,
    p_fecha_salida DATE DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_costo NUMERIC DEFAULT NULL,
    p_es_externo BOOLEAN DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE bal_mantenimiento
    SET
        id_tipo_mantenimiento = COALESCE(p_id_tipo_mantenimiento, id_tipo_mantenimiento),
        fecha_ingreso = COALESCE(p_fecha_ingreso, fecha_ingreso),
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        descripcion = COALESCE(p_descripcion, descripcion),
        costo = COALESCE(p_costo, costo),
        es_externo = COALESCE(p_es_externo, es_externo),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_mantenimiento(p_id);
END;
$function$;
