CREATE OR REPLACE FUNCTION bal_solicitar_baja_balon(
    p_id_balon INTEGER,
    p_id_motivo_baja INTEGER,
    p_id_usuario_solicita INTEGER,
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
    v_nombre_motivo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_motivo_baja IS NULL THEN
        RETURN json_build_object('error', 'El motivo de baja es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_usuario_solicita IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el usuario solicitante', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_baja_balon
        WHERE id_balon = p_id_balon
          AND estado = 1
          AND estado_aprobacion IN ('PENDIENTE', 'APROBADA')
    ) THEN
        RETURN json_build_object('error', 'El balón ya tiene una solicitud o baja activa', 'registro', NULL);
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

    INSERT INTO bal_baja_balon (
        id_balon, id_motivo_baja, fecha_baja,
        id_usuario_solicita, estado_aprobacion,
        motivo_detalle, id_cliente_comprador, id_comprobante_venta,
        serie_comprobante, numero_comprobante, monto_venta, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_motivo_baja, COALESCE(p_fecha_baja, CURRENT_DATE),
        p_id_usuario_solicita, 'PENDIENTE',
        NULLIF(TRIM(p_motivo_detalle), ''), p_id_cliente_comprador, p_id_comprobante_venta,
        p_serie_comprobante, p_numero_comprobante, p_monto_venta, p_observacion,
        COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita),
        COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita)
    )
    RETURNING id INTO v_id_baja;

    RETURN bal_obtener_baja_balon(v_id_baja);
END;
$function$;
