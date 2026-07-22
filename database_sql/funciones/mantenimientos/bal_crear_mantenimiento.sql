CREATE OR REPLACE FUNCTION bal_crear_mantenimiento(
    p_id_balon INTEGER,
    p_fecha_ingreso DATE,
    p_id_tipo_mantenimiento INTEGER DEFAULT NULL,
    p_fecha_salida DATE DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_costo NUMERIC DEFAULT 0,
    p_es_externo BOOLEAN DEFAULT FALSE,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_vigencia_ph_anios INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT NULL,
    p_numero_certificado_ph VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_estado_mantenimiento INTEGER;
    v_id_almacen INTEGER;
    v_id_cliente INTEGER;
    v_mov_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_ingreso IS NULL THEN
        RETURN json_build_object('error', 'La fecha de ingreso es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT id_almacen, id_cliente_ubicacion
    INTO v_id_almacen, v_id_cliente
    FROM bal_balon
    WHERE id = p_id_balon AND estado = 1;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_MANTENIMIENTO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'MANTENIMIENTO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_mantenimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_MANTENIMIENTO' AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_mantenimiento (
        id_balon, id_tipo_mantenimiento, fecha_ingreso, fecha_salida,
        descripcion, costo, es_externo, id_proveedor, id_estado,
        id_comprobante_venta, id_comprobante_compra, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_tipo_mantenimiento, p_fecha_ingreso, p_fecha_salida,
        p_descripcion, COALESCE(p_costo, 0), COALESCE(p_es_externo, FALSE), p_id_proveedor, p_id_estado,
        p_id_comprobante_venta, p_id_comprobante_compra, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF v_id_tipo_movimiento IS NOT NULL THEN
        v_mov_result := bal_crear_movimiento(
            p_id_balon,
            v_id_tipo_movimiento,
            v_id,
            v_id_tipo_documento_ref,
            v_id_cliente,
            v_id_almacen,
            NULL,
            p_fecha_ingreso::TIMESTAMP,
            COALESCE(p_observacion, 'Salida a mantenimiento'),
            p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = COALESCE(v_id_estado_mantenimiento, id_estado_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_sync_ph_desde_mantenimiento(
        v_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(v_id);
END;
$function$;
