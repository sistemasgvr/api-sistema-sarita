-- Agrega una línea a una compra existente (solo si aún no tiene
-- movimientos de inventario en ninguna de sus líneas)

CREATE OR REPLACE FUNCTION com_crear_compra_detalle(
    p_id_comprobante         INTEGER,
    p_id_producto            INTEGER,
    p_cantidad               NUMERIC,
    p_precio_unitario        NUMERIC DEFAULT 0,
    p_id_clasificacion_gasto INTEGER DEFAULT NULL,
    p_descripcion            VARCHAR DEFAULT NULL,
    p_id_unidad_medida       INTEGER DEFAULT NULL,
    p_id_almacen             INTEGER DEFAULT NULL,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_detalle          INTEGER;
    v_item                INTEGER;
    v_afecta_stock        BOOLEAN;
    v_id_almacen_cabecera INTEGER;
    v_id_almacen_linea    INTEGER;
    v_fecha               DATE;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_importe             NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT id_almacen, fecha, serie, numero
    INTO v_id_almacen_cabecera, v_fecha, v_serie, v_numero
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1;

    IF v_id_almacen_cabecera IS NULL THEN
        RETURN json_build_object('error', 'La compra indicada no existe o está anulada', 'registro', NULL);
    END IF;

    -- Regla 1: si la compra YA tiene líneas que afectaron stock, no se
    -- puede agregar una línea más (sería una modificación parcial).
    IF com_tiene_movimientos_inventario(p_id_comprobante) THEN
        RETURN json_build_object(
            'error', 'Esta compra ya generó movimientos de inventario y no admite modificación parcial. Anule la compra completa y registre una nueva referenciándola.',
            'registro', NULL
        );
    END IF;

    SELECT afecta_stock INTO v_afecta_stock
    FROM pro_producto
    WHERE id = p_id_producto AND estado = 1;

    IF v_afecta_stock IS NULL THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_id_almacen_linea := COALESCE(p_id_almacen, v_id_almacen_cabecera);

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(item), 0) + 1 INTO v_item
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante;

    v_importe := p_cantidad * p_precio_unitario;

    v_descripcion_linea := p_descripcion;
    IF v_descripcion_linea IS NULL THEN
        SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = p_id_producto;
    END IF;

    INSERT INTO com_comprobante_compra_detalle (
        id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
        id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
        afecta_stock, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_comprobante, v_item, p_id_clasificacion_gasto, p_id_producto, v_descripcion_linea,
        p_id_unidad_medida, v_id_almacen_linea, p_cantidad, p_precio_unitario, v_importe,
        v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_detalle;

    IF v_afecta_stock THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        v_result_movimiento := pro_crear_movimiento(
            p_fecha                 => v_fecha,
            p_id_producto           => p_id_producto,
            p_id_almacen            => v_id_almacen_linea,
            p_id_tipo_movimiento    => v_id_tipo_ingreso,
            p_cantidad              => p_cantidad,
            p_id_documento_ref      => v_id_detalle,
            p_id_tipo_documento_ref => v_id_tipo_doc_ref,
            p_glosa                 => 'Ingreso por compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria  => p_id_usuario_auditoria
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    PERFORM com_recalcular_totales_compra(p_id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;