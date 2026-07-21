CREATE OR REPLACE FUNCTION bal_aprobar_baja_balon(
    p_id_baja INTEGER,
    p_id_usuario_autoriza INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_motivo_baja INTEGER;
    v_id_usuario_solicita INTEGER;
    v_motivo_detalle VARCHAR;
    v_id_cliente_comprador INTEGER;
    v_observacion VARCHAR;
    v_fecha_baja DATE;
    v_id_movimiento INTEGER;
    v_id_estado_baja INTEGER;
    v_id_estado_anterior INTEGER;
    v_nombre_motivo VARCHAR;
    v_nombre_estado_destino VARCHAR;
    v_id_tipo_mov_venta INTEGER;
    v_id_almacen INTEGER;
    v_id_usuario INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_autoriza IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el administrador autorizador', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM auth_usuarios_roles ur
        INNER JOIN auth_roles r ON ur.id_rol = r.id
        WHERE ur.id_usuario = p_id_usuario_autoriza
          AND ur.estado = TRUE
          AND r.estado = TRUE
          AND r.nombre = 'Administrador'
    ) THEN
        RETURN json_build_object('error', 'La baja debe ser autorizada por un administrador de la empresa', 'registro', NULL);
    END IF;

    SELECT
        bb.id_balon,
        bb.id_motivo_baja,
        bb.id_usuario_solicita,
        bb.motivo_detalle,
        bb.id_cliente_comprador,
        bb.observacion,
        bb.fecha_baja
    INTO
        v_id_balon,
        v_id_motivo_baja,
        v_id_usuario_solicita,
        v_motivo_detalle,
        v_id_cliente_comprador,
        v_observacion,
        v_fecha_baja
    FROM bal_baja_balon bb
    WHERE bb.id = p_id_baja
      AND bb.estado = 1
      AND bb.estado_aprobacion = 'PENDIENTE';

    IF v_id_balon IS NULL THEN
        RETURN json_build_object('error', 'La solicitud de baja no existe o ya fue procesada', 'registro', NULL);
    END IF;

    IF v_id_usuario_solicita = p_id_usuario_autoriza THEN
        RETURN json_build_object('error', 'Un administrador distinto al solicitante debe aprobar la baja', 'registro', NULL);
    END IF;

    SELECT id_estado_balon, id_almacen
    INTO v_id_estado_anterior, v_id_almacen
    FROM bal_balon
    WHERE id = v_id_balon AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.nombre
    INTO v_nombre_motivo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE lo.id = v_id_motivo_baja
      AND l.nombre = 'MotivoBajaBalon'
      AND lo.estado = 1;

    v_nombre_estado_destino := CASE
        WHEN v_nombre_motivo = 'ROBO' THEN 'ROBO'
        ELSE 'DADO_DE_BAJA'
    END;

    SELECT lo.id INTO v_id_estado_baja
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_nombre_estado_destino AND lo.estado = 1;

    IF v_id_estado_baja IS NULL THEN
        RETURN json_build_object(
            'error',
            format('No está configurado el estado %s', v_nombre_estado_destino),
            'registro', NULL
        );
    END IF;

    v_id_usuario := COALESCE(p_id_usuario_auditoria, p_id_usuario_autoriza);

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
                v_id_balon, v_id_tipo_mov_venta, v_id_cliente_comprador,
                v_id_almacen, NOW(),
                COALESCE(v_observacion, 'Baja por venta de cilindro'),
                v_id_usuario,
                v_id_usuario
            )
            RETURNING id INTO v_id_movimiento;
        END IF;
    END IF;

    UPDATE bal_baja_balon
    SET
        estado_aprobacion = 'APROBADA',
        id_usuario_autoriza = p_id_usuario_autoriza,
        fecha_autorizacion = NOW(),
        id_movimiento = v_id_movimiento,
        id_usuario_modificacion = v_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado_baja,
        id_almacen = NULL,
        id_cliente_ubicacion = CASE WHEN v_nombre_motivo = 'VENDIDO' THEN v_id_cliente_comprador ELSE id_cliente_ubicacion END,
        id_usuario_modificacion = v_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = v_id_balon AND estado = 1;

    PERFORM bal_registrar_estado_historial(
        v_id_balon,
        'BAJA_APROBADA',
        p_id_baja,
        v_id_motivo_baja,
        v_id_estado_anterior,
        v_id_estado_baja,
        COALESCE(NULLIF(TRIM(v_observacion), ''), NULLIF(TRIM(v_motivo_detalle), ''), 'Baja aprobada'),
        v_id_usuario,
        NOW()
    );

    RETURN bal_obtener_baja_balon(p_id_baja);
END;
$function$;
