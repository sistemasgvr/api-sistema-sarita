CREATE OR REPLACE FUNCTION com_anular_compra(
    p_id_comprobante         INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_id_almacen_default  INTEGER;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_id_tipo_salida      INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
    v_faltantes           TEXT := '';
    v_nombre_producto     VARCHAR;
    v_nombre_almacen      VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_almacen, serie, numero
    INTO v_id_almacen_default, v_serie, v_numero
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF v_id_almacen_default IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante);
    END IF;

    SELECT glo.id INTO v_id_tipo_salida
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'SALIDA' AND glo.estado = 1;

    SELECT glo.id INTO v_id_tipo_doc_ref
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'DEVOLUCION' AND glo.estado = 1;

    -- ---------- PASO 1: VALIDACIÓN COMPLETA (sin modificar nada aún) ----------
    -- Se bloquean (FOR UPDATE) las filas de pro_stock involucradas para que
    -- ninguna venta/compra concurrente cambie el stock entre esta validación
    -- y la reversa real del paso 2 (misma transacción, mismo lock).
    FOR v_detalle IN
        SELECT d.id, d.id_producto, d.cantidad,
               COALESCE(d.id_almacen, v_id_almacen_default) AS id_almacen
        FROM com_comprobante_compra_detalle d
        WHERE d.id_comprobante = p_id_comprobante
          AND d.afecta_stock = TRUE
          AND d.estado = 1
    LOOP
        SELECT stock INTO v_stock_actual
        FROM pro_stock
        WHERE id_producto = v_detalle.id_producto
          AND id_almacen = v_detalle.id_almacen
          AND estado = 1
        FOR UPDATE;

        v_stock_actual := COALESCE(v_stock_actual, 0);

        IF v_stock_actual < v_detalle.cantidad THEN
            SELECT nombre INTO v_nombre_producto FROM pro_producto WHERE id = v_detalle.id_producto;
            SELECT nombre INTO v_nombre_almacen FROM gen_almacen WHERE id = v_detalle.id_almacen;

            v_faltantes := v_faltantes || format(
                E'\n- %s en %s: ingresó %s, disponible %s, falta %s',
                v_nombre_producto, v_nombre_almacen,
                v_detalle.cantidad, v_stock_actual, (v_detalle.cantidad - v_stock_actual)
            );
        END IF;
    END LOOP;

    IF v_faltantes <> '' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id_comprobante,
            'error', 'No se puede anular: el stock ya fue consumido por ventas u otros movimientos posteriores. Regularice el inventario antes de anular.' || v_faltantes
        );
    END IF;

    -- ---------- PASO 2: REVERSA REAL (ya validado que hay stock suficiente) ----------
    FOR v_detalle IN
        SELECT id, id_producto, cantidad, COALESCE(id_almacen, v_id_almacen_default) AS id_almacen
        FROM com_comprobante_compra_detalle
        WHERE id_comprobante = p_id_comprobante
          AND afecta_stock = TRUE
          AND estado = 1
    LOOP
        v_result_movimiento := pro_crear_movimiento(
            p_fecha                 => CURRENT_DATE,
            p_id_producto           => v_detalle.id_producto,
            p_id_almacen            => v_detalle.id_almacen,
            p_id_tipo_movimiento    => v_id_tipo_salida,
            p_cantidad              => v_detalle.cantidad,
            p_id_documento_ref      => v_detalle.id,
            p_id_tipo_documento_ref => v_id_tipo_doc_ref,
            p_glosa                 => 'Reversa por anulación de compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria  => p_id_usuario_auditoria
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo anular: %', v_result_movimiento->>'error';
        END IF;
    END LOOP;

    UPDATE com_comprobante_compra
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id_comprobante;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_comprobante);
END;
$function$;