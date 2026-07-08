CREATE OR REPLACE FUNCTION bal_dar_baja_balon(
    p_id_balon INTEGER,
    p_id_motivo_baja INTEGER,
    p_id_usuario_solicita INTEGER,
    p_id_usuario_autoriza INTEGER,
    p_motivo_detalle VARCHAR DEFAULT NULL,
    p_id_cliente_comprador INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_serie_comprobante VARCHAR DEFAULT NULL,
    p_numero_comprobante VARCHAR DEFAULT NULL,
    p_monto_venta NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_fecha_baja DATE DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_baja INTEGER;
    v_id_movimiento INTEGER;
    v_id_estado_baja INTEGER;
    v_nombre_motivo VARCHAR;
    v_id_tipo_mov_venta INTEGER;
    v_id_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_motivo_baja IS NULL THEN
        RETURN json_build_object('error', 'El motivo de baja es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_usuario_solicita IS NULL OR p_id_usuario_autoriza IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar usuario solicitante y administrador autorizador', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM auth_usuarios_roles ur
        INNER JOIN auth_roles r ON ur.id_rol = r.id
        WHERE ur.id_usuario = p_id_usuario_autoriza
          AND ur.estado = TRUE
          AND r.estado = 1
          AND r.nombre = 'Administrador'
    ) THEN
        RETURN json_build_object('error', 'La baja debe ser autorizada por un administrador de la empresa', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM bal_baja_balon WHERE id_balon = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('error', 'El balón ya tiene un registro de baja activo', 'registro', NULL);
    END IF;

    SELECT lo.nombre
    INTO v_nombre_motivo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE lo.id = p_id_motivo_baja
      AND l.nombre = 'MotivoBajaBalon'
      AND lo.estado = 1;

    IF v_nombre_motivo IS NULL THEN
        RETURN json_build_object('error', 'El motivo de baja indicado no es válido', 'registro', NULL);
    END IF;

    IF v_nombre_motivo = 'OTROS' AND (p_motivo_detalle IS NULL OR TRIM(p_motivo_detalle) = '') THEN
        RETURN json_build_object('error', 'Debe indicar el detalle cuando el motivo de baja es OTROS', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_baja
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DADO_DE_BAJA' AND lo.estado = 1;

    IF v_id_estado_baja IS NULL THEN
        RETURN json_build_object('error', 'No está configurado el estado DADO_DE_BAJA', 'registro', NULL);
    END IF;

    SELECT id_almacen INTO v_id_almacen FROM bal_balon WHERE id = p_id_balon;

    INSERT INTO bal_baja_balon (
        id_balon, id_motivo_baja, fecha_baja,
        id_usuario_solicita, id_usuario_autoriza, fecha_autorizacion,
        motivo_detalle, id_cliente_comprador, id_comprobante_venta,
        serie_comprobante, numero_comprobante, monto_venta, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_motivo_baja, COALESCE(p_fecha_baja, CURRENT_DATE),
        p_id_usuario_solicita, p_id_usuario_autoriza, NOW(),
        NULLIF(TRIM(p_motivo_detalle), ''), p_id_cliente_comprador, p_id_comprobante_venta,
        p_serie_comprobante, p_numero_comprobante, p_monto_venta, p_observacion,
        COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita),
        COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita)
    )
    RETURNING id INTO v_id_baja;

    IF v_nombre_motivo = 'VENDIDO' THEN
        SELECT lo.id INTO v_id_tipo_mov_venta
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_VENTA' AND lo.estado = 1;

        IF v_id_tipo_mov_venta IS NOT NULL THEN
            INSERT INTO bal_movimiento (
                id_balon, id_tipo_movimiento, id_cliente,
                id_almacen_origen, fecha_movimiento, observacion,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id_balon, v_id_tipo_mov_venta, p_id_cliente_comprador,
                v_id_almacen, NOW(),
                COALESCE(p_observacion, 'Baja por venta de cilindro'),
                COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita),
                COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita)
            )
            RETURNING id INTO v_id_movimiento;

            UPDATE bal_baja_balon
            SET id_movimiento = v_id_movimiento
            WHERE id = v_id_baja;
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado_baja,
        id_almacen = NULL,
        id_cliente_ubicacion = CASE WHEN v_nombre_motivo = 'VENDIDO' THEN p_id_cliente_comprador ELSE id_cliente_ubicacion END,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita),
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN bal_obtener_baja_balon(v_id_baja);
END;
$function$;
