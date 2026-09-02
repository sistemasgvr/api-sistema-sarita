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
    v_motivo_detalle VARCHAR;
    v_id_cliente_comprador INTEGER;
    v_id_comprobante_venta INTEGER;
    v_observacion VARCHAR;
    v_fecha_baja DATE;
    v_id_movimiento INTEGER;
    v_id_estado_baja INTEGER;
    v_id_estado_anterior INTEGER;
    v_nombre_motivo VARCHAR;
    v_nombre_estado_destino VARCHAR;
    v_id_almacen INTEGER;
    v_id_usuario INTEGER;
    v_codigo_tipo_comp VARCHAR;
    v_codigo_tipo_doc_ref VARCHAR;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_autoriza IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el administrador autorizador', 'registro', NULL);
    END IF;

    -- Rol Administrador + permiso bajas_balon.aprobar (o auth.todo). Permite auto-aprobación.
    IF NOT auth_usuario_es_admin_con_permiso(p_id_usuario_autoriza, 'bajas_balon.aprobar') THEN
        RETURN json_build_object(
            'error',
            'La baja debe ser autorizada por un administrador con permiso de aprobar bajas de cilindro',
            'registro',
            NULL
        );
    END IF;

    SELECT
        bb.id_balon,
        bb.id_motivo_baja,
        bb.motivo_detalle,
        bb.id_cliente_comprador,
        bb.id_comprobante_venta,
        bb.observacion,
        bb.fecha_baja
    INTO
        v_id_balon,
        v_id_motivo_baja,
        v_motivo_detalle,
        v_id_cliente_comprador,
        v_id_comprobante_venta,
        v_observacion,
        v_fecha_baja
    FROM bal_baja_balon bb
    WHERE bb.id = p_id_baja
      AND bb.estado = 1
      AND bb.estado_aprobacion = 'PENDIENTE';

    IF v_id_balon IS NULL THEN
        RETURN json_build_object('error', 'La solicitud de baja no existe o ya fue procesada', 'registro', NULL);
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
        v_codigo_tipo_doc_ref := NULL;
        IF v_id_comprobante_venta IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_tipo_comp
            FROM ven_comprobante c
            INNER JOIN gen_lista_opciones lo ON lo.id = c.id_tipo_comprobante
            WHERE c.id = v_id_comprobante_venta AND c.estado = 1;

            v_codigo_tipo_doc_ref := CASE
                WHEN v_codigo_tipo_comp = '01' THEN 'FACTURA'
                WHEN v_codigo_tipo_comp = '03' THEN 'BOLETA'
                WHEN v_codigo_tipo_comp IN ('NV', 'VSD') THEN 'NOTA_VENTA'
                ELSE 'FACTURA'
            END;
        END IF;

        -- Movimiento SALIDA_VENTA con trazabilidad al comprobante (estado lo aplica esta función)
        v_mov := bal_registrar_salida_documento(
            v_id_balon,
            'SALIDA_VENTA',
            v_id_comprobante_venta,
            v_codigo_tipo_doc_ref,
            v_id_cliente_comprador,
            v_id_almacen,
            NULL,
            FALSE,
            NULL,
            COALESCE(v_observacion, 'Baja por venta de cilindro'),
            v_id_usuario
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
        END IF;

        v_id_movimiento := (v_mov->'registro'->>'id')::INTEGER;
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
        presion_actual = NULL,
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
