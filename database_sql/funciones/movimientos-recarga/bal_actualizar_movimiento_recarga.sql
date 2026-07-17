CREATE OR REPLACE FUNCTION bal_actualizar_movimiento_recarga(
    p_id INTEGER,
    p_fecha_salida_almacen DATE DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_serie_guia_salida VARCHAR DEFAULT NULL,
    p_numero_guia_salida VARCHAR DEFAULT NULL,
    p_serie_guia_ingreso VARCHAR DEFAULT NULL,
    p_numero_guia_ingreso VARCHAR DEFAULT NULL,
    p_serie_factura VARCHAR DEFAULT NULL,
    p_numero_factura VARCHAR DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_fecha_llegada_almacen DATE DEFAULT NULL,
    p_lote VARCHAR DEFAULT NULL,
    p_fecha_vencimiento_lote DATE DEFAULT NULL,
    p_fecha_prueba_hidrostatica DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE bal_movimiento_recarga
    SET
        fecha_salida_almacen = COALESCE(p_fecha_salida_almacen, fecha_salida_almacen),
        id_producto = COALESCE(p_id_producto, id_producto),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        serie_guia_salida = COALESCE(p_serie_guia_salida, serie_guia_salida),
        numero_guia_salida = COALESCE(p_numero_guia_salida, numero_guia_salida),
        serie_guia_ingreso = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
        serie_factura = COALESCE(p_serie_factura, serie_factura),
        numero_factura = COALESCE(p_numero_factura, numero_factura),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        observacion = COALESCE(p_observacion, observacion),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_movimiento_recarga(p_id);
END;
$function$;
