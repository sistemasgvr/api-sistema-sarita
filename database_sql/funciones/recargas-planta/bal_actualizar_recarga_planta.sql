CREATE OR REPLACE FUNCTION bal_actualizar_recarga_planta(
    p_id INTEGER,
    p_fecha_salida DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_guia_retorno INTEGER DEFAULT NULL,
    p_serie_guia_ingreso VARCHAR DEFAULT NULL,
    p_numero_guia_ingreso VARCHAR DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_serie_factura VARCHAR DEFAULT NULL,
    p_numero_factura VARCHAR DEFAULT NULL,
    p_fecha_llegada_almacen DATE DEFAULT NULL,
    p_lote VARCHAR DEFAULT NULL,
    p_fecha_vencimiento_lote DATE DEFAULT NULL,
    p_fecha_prueba_hidrostatica DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_actual VARCHAR;
    v_id_estado INTEGER;
    v_det RECORD;
    v_upd JSON;
    v_fecha_llegada DATE;
    v_id_compra INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_recarga_planta WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'Orden de recarga no encontrada', 'registro', NULL);
    END IF;

    SELECT est.nombre
    INTO v_estado_actual
    FROM bal_recarga_planta rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
    WHERE rp.id = p_id;

    IF p_id_guia_retorno IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gre_guia_remision WHERE id = p_id_guia_retorno AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La guía de retorno no existe', 'registro', NULL);
    END IF;

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de compra no existe', 'registro', NULL);
    END IF;

    UPDATE bal_recarga_planta
    SET
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_guia_retorno = COALESCE(p_id_guia_retorno, id_guia_retorno),
        serie_guia_ingreso = COALESCE(NULLIF(TRIM(p_serie_guia_ingreso), ''), serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(NULLIF(TRIM(p_numero_guia_ingreso), ''), numero_guia_ingreso),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        serie_factura = COALESCE(NULLIF(TRIM(p_serie_factura), ''), serie_factura),
        numero_factura = COALESCE(NULLIF(TRIM(p_numero_factura), ''), numero_factura),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = COALESCE(NULLIF(TRIM(p_lote), ''), lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    -- Propagar retorno a cada movimiento de recarga hijo
    IF p_fecha_llegada_almacen IS NOT NULL
       OR p_lote IS NOT NULL
       OR p_id_comprobante_compra IS NOT NULL
       OR p_serie_guia_ingreso IS NOT NULL
    THEN
        FOR v_det IN
            SELECT d.id_movimiento_recarga, d.id, d.id_producto, d.capacidad, d.id_unidad_medida
            FROM bal_recarga_planta_detalle d
            WHERE d.id_recarga_planta = p_id
              AND d.estado = 1
              AND d.id_movimiento_recarga IS NOT NULL
        LOOP
            UPDATE bal_recarga_planta_detalle
            SET
                lote = COALESCE(NULLIF(TRIM(p_lote), ''), lote),
                fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
                fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id;

            v_upd := bal_actualizar_movimiento_recarga(
                v_det.id_movimiento_recarga,
                NULL,
                v_det.id_producto,
                v_det.capacidad,
                v_det.id_unidad_medida,
                NULL,
                NULL,
                NULLIF(TRIM(p_serie_guia_ingreso), ''),
                NULLIF(TRIM(p_numero_guia_ingreso), ''),
                NULLIF(TRIM(p_serie_factura), ''),
                NULLIF(TRIM(p_numero_factura), ''),
                NULL,
                p_fecha_llegada_almacen,
                NULLIF(TRIM(p_lote), ''),
                p_fecha_vencimiento_lote,
                p_fecha_prueba_hidrostatica,
                NULL,
                NULL,
                NULL,
                p_id_comprobante_compra,
                p_id_usuario_auditoria
            );

            IF v_upd->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_upd->>'error', 'registro', NULL);
            END IF;
        END LOOP;
    END IF;

    -- CERRADO solo con compra + retorno físico. Solo llegada → RETORNADO.
    -- Solo vincular compra (sin llegada) no cierra la orden.
    SELECT fecha_llegada_almacen, id_comprobante_compra
    INTO v_fecha_llegada, v_id_compra
    FROM bal_recarga_planta
    WHERE id = p_id;

    IF v_id_compra IS NOT NULL AND v_fecha_llegada IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'CERRADO' AND lo.estado = 1
        LIMIT 1;
    ELSIF v_fecha_llegada IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'RETORNADO' AND lo.estado = 1
        LIMIT 1;
    ELSE
        v_id_estado := NULL;
    END IF;

    IF v_id_estado IS NOT NULL THEN
        UPDATE bal_recarga_planta
        SET id_estado = v_id_estado
        WHERE id = p_id;
    END IF;

    RETURN bal_obtener_recarga_planta(p_id);
END;
$function$;
