CREATE OR REPLACE FUNCTION bal_actualizar_prestamo(
    p_id INTEGER,
    p_numero_prestamo VARCHAR DEFAULT NULL,
    p_id_tipo_prestamo INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_fecha_salida DATE DEFAULT NULL,
    p_fecha_retorno_pactada DATE DEFAULT NULL,
    p_fecha_retorno_real DATE DEFAULT NULL,
    p_titulo VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero := NULLIF(TRIM(p_numero_prestamo), '');

    IF v_numero IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_prestamo WHERE numero_prestamo = v_numero AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro préstamo con el número ' || v_numero, 'registro', NULL);
    END IF;

    UPDATE bal_prestamo
    SET
        numero_prestamo = COALESCE(v_numero, numero_prestamo),
        id_tipo_prestamo = COALESCE(p_id_tipo_prestamo, id_tipo_prestamo),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        fecha_retorno_pactada = COALESCE(p_fecha_retorno_pactada, fecha_retorno_pactada),
        fecha_retorno_real = COALESCE(p_fecha_retorno_real, fecha_retorno_real),
        titulo = COALESCE(p_titulo, titulo),
        observacion = COALESCE(p_observacion, observacion),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_prestamo(p_id);
END;
$function$;
