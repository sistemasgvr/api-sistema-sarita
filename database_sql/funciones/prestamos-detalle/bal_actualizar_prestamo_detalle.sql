CREATE OR REPLACE FUNCTION bal_actualizar_prestamo_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_motivo_especifico VARCHAR DEFAULT NULL,
    p_fecha_entregado DATE DEFAULT NULL,
    p_fecha_prestamo DATE DEFAULT NULL,
    p_dias_prestamo INTEGER DEFAULT NULL,
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
    v_id_prestamo INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen INTEGER;
    v_id_cliente INTEGER;
    v_id_balon_nuevo INTEGER;
    v_id_producto INTEGER;
    v_nombre_estado_nuevo VARCHAR;
    v_retorno JSON;
    v_salida JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.id_producto,
        p.id_almacen,
        p.id_cliente
    INTO
        v_id_prestamo,
        v_id_balon_actual,
        v_fecha_devolucion,
        v_id_producto,
        v_id_almacen,
        v_id_cliente
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id AND pd.estado = 1;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object('error', 'El detalle de préstamo no existe o está inactivo', 'registro', NULL);
    END IF;

    v_id_balon_nuevo := COALESCE(p_id_balon, v_id_balon_actual);

    IF p_id_estado IS NOT NULL THEN
        SELECT lo.nombre INTO v_nombre_estado_nuevo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_estado AND lo.estado = 1;
    END IF;

    -- Devolver por fecha/estado en el formulario de edición → misma custodia que "Devolver".
    IF v_fecha_devolucion IS NULL
       AND (
           p_fecha_devolucion IS NOT NULL
           OR UPPER(COALESCE(v_nombre_estado_nuevo, '')) = 'DEVUELTO'
       )
    THEN
        RETURN bal_devolver_prestamo_detalle(
            p_id,
            COALESCE(p_fecha_devolucion, CURRENT_DATE),
            v_id_almacen,
            p_id_usuario_auditoria,
            'VACIO',
            p_observacion
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL
       AND p_id_balon IS NOT NULL
       AND p_id_balon IS DISTINCT FROM v_id_balon_actual
    THEN
        RETURN json_build_object(
            'error', 'No se puede cambiar el cilindro de un detalle ya devuelto',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NULL
       AND p_id_balon IS NOT NULL
       AND p_id_balon IS DISTINCT FROM v_id_balon_actual
    THEN
        IF v_id_balon_actual IS NOT NULL THEN
            IF v_id_almacen IS NULL THEN
                SELECT id INTO v_id_almacen FROM gen_almacen WHERE estado = 1 ORDER BY id LIMIT 1;
            END IF;

            v_retorno := bal_prestamo_aplicar_retorno_cilindro(
                v_id_balon_actual,
                v_id_prestamo,
                v_id_cliente,
                v_id_almacen,
                NULL,
                'Cambio de cilindro en préstamo (libera el anterior)',
                p_id_usuario_auditoria,
                TRUE
            );
            IF v_retorno->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_retorno->>'error', 'registro', NULL);
            END IF;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon_nuevo
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
              AND pd.id <> p_id
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un préstamo activo sin devolver',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = v_id_balon_nuevo
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está alquilado actualmente; no se puede prestar',
                'registro', NULL
            );
        END IF;

        v_salida := bal_prestamo_aplicar_salida_cilindro(
            v_id_prestamo,
            v_id_balon_nuevo,
            COALESCE(p_observacion, 'Cambio de cilindro en préstamo'),
            p_id_usuario_auditoria
        );
        IF v_salida->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_salida->>'error', 'registro', NULL);
        END IF;
    END IF;

    IF v_id_balon_nuevo IS NOT NULL THEN
        SELECT COALESCE(b.id_producto_gas, COALESCE(p_id_producto, v_id_producto))
        INTO v_id_producto
        FROM bal_balon b
        WHERE b.id = v_id_balon_nuevo AND b.estado = 1;
    ELSE
        v_id_producto := COALESCE(p_id_producto, v_id_producto);
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_producto = COALESCE(v_id_producto, id_producto),
        motivo_especifico = COALESCE(p_motivo_especifico, motivo_especifico),
        fecha_entregado = COALESCE(p_fecha_entregado, fecha_entregado),
        fecha_prestamo = COALESCE(p_fecha_prestamo, fecha_prestamo),
        dias_prestamo = COALESCE(p_dias_prestamo, dias_prestamo),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        serie_guia_entrega = COALESCE(p_serie_guia_entrega, serie_guia_entrega),
        numero_guia_entrega = COALESCE(p_numero_guia_entrega, numero_guia_entrega),
        serie_guia_devolucion = COALESCE(p_serie_guia_devolucion, serie_guia_devolucion),
        numero_guia_devolucion = COALESCE(p_numero_guia_devolucion, numero_guia_devolucion),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;
