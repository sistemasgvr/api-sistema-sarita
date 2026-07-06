CREATE OR REPLACE FUNCTION bal_crear_alquiler(
    p_numero_alquiler VARCHAR,
    p_id_cliente INTEGER,
    p_id_almacen INTEGER,
    p_fecha_inicio DATE,
    p_fecha_fin_pactada DATE DEFAULT NULL,
    p_fecha_fin_real DATE DEFAULT NULL,
    p_tarifa_diaria NUMERIC DEFAULT 0,
    p_total_cobrado NUMERIC DEFAULT 0,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_numero_alquiler IS NULL OR TRIM(p_numero_alquiler) = '' THEN
        RETURN json_build_object('error', 'El número de alquiler es obligatorio', 'registro', NULL);
    END IF;

    IF p_fecha_inicio IS NULL THEN
        RETURN json_build_object('error', 'La fecha de inicio es obligatoria', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(TRIM(p_numero_alquiler))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un alquiler con el número ' || TRIM(p_numero_alquiler), 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_alquiler (
        numero_alquiler, id_cliente, id_almacen, fecha_inicio,
        fecha_fin_pactada, fecha_fin_real, tarifa_diaria, total_cobrado,
        id_estado, observacion, id_comprobante_venta,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_numero_alquiler), p_id_cliente, p_id_almacen, p_fecha_inicio,
        p_fecha_fin_pactada, p_fecha_fin_real, COALESCE(p_tarifa_diaria, 0), COALESCE(p_total_cobrado, 0),
        p_id_estado, p_observacion, p_id_comprobante_venta,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_alquiler(v_id);
END;
$function$;
