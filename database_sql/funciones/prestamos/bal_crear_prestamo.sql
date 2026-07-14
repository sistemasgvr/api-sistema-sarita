CREATE OR REPLACE FUNCTION bal_crear_prestamo(
    p_id_tipo_prestamo INTEGER,
    p_numero_prestamo VARCHAR DEFAULT NULL,
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
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_prestamo IS NULL THEN
        RETURN json_build_object('error', 'El tipo de préstamo es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_numero_prestamo IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_prestamo WHERE numero_prestamo = TRIM(p_numero_prestamo)
    ) THEN
        RETURN json_build_object('error', 'Ya existe un préstamo con el número ' || TRIM(p_numero_prestamo), 'registro', NULL);
    END IF;

    INSERT INTO bal_prestamo (
        numero_prestamo, id_tipo_prestamo, id_cliente, id_proveedor, id_almacen,
        fecha_salida, fecha_retorno_pactada, fecha_retorno_real,
        titulo, observacion, id_estado,
        id_comprobante_venta, id_comprobante_compra,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        NULLIF(TRIM(p_numero_prestamo), ''), p_id_tipo_prestamo, p_id_cliente, p_id_proveedor, p_id_almacen,
        p_fecha_salida, p_fecha_retorno_pactada, p_fecha_retorno_real,
        p_titulo, p_observacion, p_id_estado,
        p_id_comprobante_venta, p_id_comprobante_compra,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_prestamo(v_id);
END;
$function$;
