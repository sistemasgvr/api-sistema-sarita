CREATE OR REPLACE FUNCTION bal_crear_alquiler(
    p_numero_alquiler VARCHAR DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_fecha_inicio DATE DEFAULT NULL,
    p_fecha_fin_pactada DATE DEFAULT NULL,
    p_fecha_fin_real DATE DEFAULT NULL,
    p_tarifa_diaria NUMERIC DEFAULT 0,
    p_total_cobrado NUMERIC DEFAULT 0,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_producto_regulador INTEGER DEFAULT NULL,
    p_id_producto_stock INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero VARCHAR;
    v_corr JSON;
    v_prod RECORD;
    v_id_tipo_salida INTEGER;
    v_id_tipo_doc INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero := NULLIF(TRIM(p_numero_alquiler), '');
    IF v_numero IS NULL THEN
        v_corr := bal_obtener_siguiente_numero_alquiler();
        IF v_corr->>'error' IS NOT NULL OR NULLIF(v_corr->>'numero', '') IS NULL THEN
            RETURN json_build_object(
                'error', COALESCE(v_corr->>'error', 'No se pudo generar el número de alquiler'),
                'registro', NULL
            );
        END IF;
        v_numero := v_corr->>'numero';
    END IF;

    IF p_fecha_inicio IS NULL THEN
        RETURN json_build_object('error', 'La fecha de inicio es obligatoria', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(v_numero)
    ) THEN
        RETURN json_build_object('error', 'Ya existe un alquiler con el número ' || v_numero, 'registro', NULL);
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

    IF p_id_producto_regulador IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM pro_producto
        WHERE id = p_id_producto_regulador
          AND estado = 1
          AND COALESCE(es_alquilable, FALSE) = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El producto debe ser alquilable y estar activo',
            'registro', NULL
        );
    END IF;

    IF p_id_producto_stock IS NOT NULL THEN
        SELECT
            p.id,
            COALESCE(p.afecta_stock, FALSE) AS afecta_stock,
            COALESCE(p.es_servicio, FALSE) AS es_servicio,
            COALESCE(p.es_gas, FALSE) AS es_gas
        INTO v_prod
        FROM pro_producto p
        WHERE p.id = p_id_producto_stock AND p.estado = 1;

        IF v_prod.id IS NULL THEN
            RETURN json_build_object(
                'error', 'El regulador de stock indicado no existe o está inactivo',
                'registro', NULL
            );
        END IF;

        IF v_prod.es_servicio OR v_prod.es_gas THEN
            RETURN json_build_object(
                'error', 'El regulador de stock debe ser un accesorio físico (no servicio ni gas)',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_alquiler (
        numero_alquiler, id_cliente, id_almacen, fecha_inicio,
        fecha_fin_pactada, fecha_fin_real, tarifa_diaria, total_cobrado,
        id_estado, observacion, id_comprobante_venta, id_producto_regulador,
        id_producto_stock,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_numero, p_id_cliente, p_id_almacen, p_fecha_inicio,
        p_fecha_fin_pactada, p_fecha_fin_real, COALESCE(p_tarifa_diaria, 0), COALESCE(p_total_cobrado, 0),
        p_id_estado, p_observacion, p_id_comprobante_venta, p_id_producto_regulador,
        p_id_producto_stock,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_id_producto_stock IS NOT NULL AND COALESCE(v_prod.afecta_stock, FALSE) THEN
        SELECT lo.id INTO v_id_tipo_salida
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_salida IS NULL THEN
            RAISE EXCEPTION 'No se encontró el tipo de movimiento SALIDA (TipoMovInv)';
        END IF;

        v_mov := pro_crear_movimiento(
            p_fecha_inicio,
            p_id_producto_stock,
            p_id_almacen,
            v_id_tipo_salida,
            1,
            v_id,
            v_id_tipo_doc,
            'Salida por alquiler ' || v_numero,
            p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_alquiler(v_id);
END;
$function$;
