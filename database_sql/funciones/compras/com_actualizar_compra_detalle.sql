-- Actualiza cantidad y/o precio de una línea de compra activa.
-- Si afecta_stock y cambia la cantidad:
--   aumento  → INGRESO por el diferencial
--   disminución → SALIDA por el diferencial (valida stock disponible)

CREATE OR REPLACE FUNCTION com_actualizar_compra_detalle(
    p_id_detalle             INTEGER,
    p_cantidad               NUMERIC DEFAULT NULL,
    p_precio_unitario        NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_nueva_cantidad      NUMERIC(12,4);
    v_nuevo_precio        NUMERIC(12,6);
    v_delta               NUMERIC(12,4);
    v_importe             NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_salida      INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_doc_dev     INTEGER;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.precio_unitario,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.fecha,
        c.serie,
        c.numero
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    WHERE d.id = p_id_detalle
      AND d.estado = 1
      AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('error', 'La línea no existe o la compra está anulada', 'registro', NULL);
    END IF;

    v_nueva_cantidad := COALESCE(p_cantidad, v_detalle.cantidad);
    v_nuevo_precio := COALESCE(p_precio_unitario, v_detalle.precio_unitario);

    IF v_nueva_cantidad IS NULL OR v_nueva_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_nuevo_precio IS NULL OR v_nuevo_precio < 0 THEN
        RETURN json_build_object('error', 'El precio unitario no puede ser negativo', 'registro', NULL);
    END IF;

    -- Sin cambios relevantes
    IF v_nueva_cantidad = v_detalle.cantidad
       AND COALESCE(v_nuevo_precio, 0) = COALESCE(v_detalle.precio_unitario, 0)
    THEN
        RETURN com_obtener_compra(v_detalle.id_comprobante);
    END IF;

    v_delta := v_nueva_cantidad - v_detalle.cantidad;

    IF v_detalle.afecta_stock AND v_delta <> 0 THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_salida
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'SALIDA' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_compra
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_dev
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'DEVOLUCION' AND glo.estado = 1;

        IF v_delta > 0 THEN
            IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_compra IS NULL THEN
                RETURN json_build_object(
                    'error', 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef)',
                    'registro', NULL
                );
            END IF;

            v_result_movimiento := pro_crear_movimiento(
                p_fecha                 => v_detalle.fecha,
                p_id_producto           => v_detalle.id_producto,
                p_id_almacen            => v_detalle.id_almacen,
                p_id_tipo_movimiento    => v_id_tipo_ingreso,
                p_cantidad              => v_delta,
                p_id_documento_ref      => v_detalle.id,
                p_id_tipo_documento_ref => v_id_tipo_doc_compra,
                p_glosa                 => 'Ajuste (+) compra ' || v_detalle.serie || '-' || v_detalle.numero,
                p_id_usuario_auditoria  => p_id_usuario_auditoria
            );
        ELSE
            IF v_id_tipo_salida IS NULL OR v_id_tipo_doc_dev IS NULL THEN
                RETURN json_build_object(
                    'error', 'Faltan configurar las opciones SALIDA (TipoMovInv) o DEVOLUCION (TipoDocumentoRef)',
                    'registro', NULL
                );
            END IF;

            SELECT stock INTO v_stock_actual
            FROM pro_stock
            WHERE id_producto = v_detalle.id_producto
              AND id_almacen = v_detalle.id_almacen
              AND estado = 1
            FOR UPDATE;

            v_stock_actual := COALESCE(v_stock_actual, 0);

            IF v_stock_actual < ABS(v_delta) THEN
                RETURN json_build_object(
                    'error', format(
                        'Stock insuficiente para disminuir la cantidad (disponible %s, requiere restar %s)',
                        v_stock_actual,
                        ABS(v_delta)
                    ),
                    'registro', NULL
                );
            END IF;

            v_result_movimiento := pro_crear_movimiento(
                p_fecha                 => CURRENT_DATE,
                p_id_producto           => v_detalle.id_producto,
                p_id_almacen            => v_detalle.id_almacen,
                p_id_tipo_movimiento    => v_id_tipo_salida,
                p_cantidad              => ABS(v_delta),
                p_id_documento_ref      => v_detalle.id,
                p_id_tipo_documento_ref => v_id_tipo_doc_dev,
                p_glosa                 => 'Ajuste (-) compra ' || v_detalle.serie || '-' || v_detalle.numero,
                p_id_usuario_auditoria  => p_id_usuario_auditoria,
                p_forzar_ajuste_stock   => TRUE
            );
        END IF;

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RETURN json_build_object('error', v_result_movimiento->>'error', 'registro', NULL);
        END IF;
    END IF;

    v_importe := v_nueva_cantidad * v_nuevo_precio;

    UPDATE com_comprobante_compra_detalle
    SET cantidad = v_nueva_cantidad,
        precio_unitario = v_nuevo_precio,
        importe = v_importe,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(v_detalle.id_comprobante);
END;
$function$;
