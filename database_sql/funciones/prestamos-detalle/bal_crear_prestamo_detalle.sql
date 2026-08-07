CREATE OR REPLACE FUNCTION bal_crear_prestamo_detalle(
    p_id_prestamo INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_motivo_especifico VARCHAR DEFAULT NULL,
    p_fecha_entregado DATE DEFAULT NULL,
    p_fecha_prestamo DATE DEFAULT NULL,
    p_dias_prestamo INTEGER DEFAULT 30,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_fecha_devolucion DATE DEFAULT NULL,
    p_serie_guia_entrega VARCHAR DEFAULT NULL,
    p_numero_guia_entrega VARCHAR DEFAULT NULL,
    p_serie_guia_devolucion VARCHAR DEFAULT NULL,
    p_numero_guia_devolucion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_cliente INTEGER;
    v_id_estado_prestado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente
    INTO v_id_cliente
    FROM bal_prestamo
    WHERE id = p_id_prestamo AND estado = 1;

    IF v_id_cliente IS NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF p_id_balon IS NOT NULL AND v_id_estado_prestado IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado PRESTADO_CLIENTE del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF p_id_balon IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = p_id_balon
              AND COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
        ) THEN
            RETURN json_build_object(
                'error',
                'No se puede prestar un cilindro dado de baja o reportado como robo',
                'registro',
                NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error',
                'El cilindro está alquilado actualmente; no se puede prestar',
                'registro',
                NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error',
                'El cilindro ya tiene un préstamo activo sin devolver',
                'registro',
                NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo_detalle (
        id_prestamo, id_balon, id_producto, motivo_especifico,
        fecha_entregado, fecha_prestamo, dias_prestamo, fecha_vencimiento, fecha_devolucion,
        serie_guia_entrega, numero_guia_entrega, serie_guia_devolucion, numero_guia_devolucion,
        id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_prestamo, p_id_balon, p_id_producto, p_motivo_especifico,
        p_fecha_entregado, p_fecha_prestamo, COALESCE(p_dias_prestamo, 30), p_fecha_vencimiento, p_fecha_devolucion,
        p_serie_guia_entrega, p_numero_guia_entrega, p_serie_guia_devolucion, p_numero_guia_devolucion,
        p_id_estado, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_id_balon IS NOT NULL AND v_id_cliente IS NOT NULL THEN
        -- En cliente no sabemos si consume el gas → contenido DESCONOCIDO.
        UPDATE bal_balon
        SET
            id_cliente_ubicacion = v_id_cliente,
            id_almacen = NULL,
            id_estado_balon = v_id_estado_prestado,
            id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
            capacidad_restante = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    RETURN bal_obtener_prestamo_detalle(v_id);
END;
$function$;
