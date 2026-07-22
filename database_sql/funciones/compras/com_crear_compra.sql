DROP FUNCTION IF EXISTS com_crear_compra;

CREATE OR REPLACE FUNCTION com_crear_compra(
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_serie VARCHAR DEFAULT NULL,
    p_numero VARCHAR DEFAULT NULL,
    p_fecha DATE DEFAULT CURRENT_DATE,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_tipo_registro INTEGER DEFAULT NULL,
    p_id_categoria_gasto INTEGER DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_moneda INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_sub_total NUMERIC DEFAULT 0,
    p_igv NUMERIC DEFAULT 0,
    p_total_importe NUMERIC DEFAULT 0,
    p_afecta_inventario BOOLEAN DEFAULT FALSE,
    p_declarar_sunat BOOLEAN DEFAULT FALSE,
    p_glosa VARCHAR DEFAULT NULL,
    p_detalles JSONB DEFAULT '[]'::JSONB,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_item JSONB;
    v_i INTEGER := 1;
    v_id_clasif INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_serie IS NOT NULL AND p_numero IS NOT NULL AND p_id_proveedor IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM com_comprobante_compra
            WHERE id_proveedor = p_id_proveedor
              AND serie = p_serie
              AND numero = p_numero
              AND estado = 1
        ) THEN
            RAISE EXCEPTION 'Ya existe un comprobante registrado con esa serie y número para este proveedor.';
        END IF;
    END IF;

    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        afecta_inventario, declarar_sunat, glosa,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, COALESCE(p_sub_total, 0), COALESCE(p_igv, 0), COALESCE(p_total_importe, 0),
        COALESCE(p_afecta_inventario, FALSE), COALESCE(p_declarar_sunat, FALSE), p_glosa,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        v_id_clasif := (v_item->>'idClasificacionGasto')::INTEGER;

        IF v_id_clasif IS NOT NULL THEN
            IF NOT EXISTS (SELECT 1 FROM gen_clasificacion_gasto WHERE id = v_id_clasif AND estado = 1) THEN
                RAISE EXCEPTION 'La clasificación de gasto seleccionada (ID %) no existe o está inactiva.', v_id_clasif;
            END IF;
        END IF;

        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto,
            descripcion, id_unidad_medida, cantidad, precio_unitario,
            importe, id_medio_pago, fecha_pago, numero_operacion,
            afecta_stock, observacion, id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id,
            v_i,
            v_id_clasif,
            (v_item->>'idProducto')::INTEGER,
            v_item->>'descripcion',
            (v_item->>'idUnidadMedida')::INTEGER,
            (v_item->>'cantidad')::NUMERIC,
            (v_item->>'precioUnitario')::NUMERIC,
            (v_item->>'importe')::NUMERIC,
            (v_item->>'idMedioPago')::INTEGER,
            NULLIF(v_item->>'fechaPago', '')::DATE,
            v_item->>'numeroOperacion',
            COALESCE((v_item->>'afectaStock')::BOOLEAN, FALSE),
            v_item->>'observacion',
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
        v_i := v_i + 1;
    END LOOP;

    RETURN com_obtener_compra(v_id);
END;
$function$;