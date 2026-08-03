-- p_id_comprobante_referencia: opcional. Si se indica, esta compra
-- nueva "corrige" a la compra referenciada, la cual DEBE estar
-- anulada (estado=0) — no se permite referenciar una compra activa.
--
-- precio_unitario en los detalles se asume CON IGV incluido (es lo que
-- factura el proveedor). Al guardar se descompone en base imponible
-- (sub_total) + IGV (igv), igual que en ven_crear_comprobante.

CREATE OR REPLACE FUNCTION com_crear_compra(
    p_id_tipo_comprobante        INTEGER,
    p_serie                      VARCHAR,
    p_numero                     VARCHAR,
    p_fecha                      DATE,
    p_id_proveedor               INTEGER,
    p_id_almacen                 INTEGER,
    p_detalles                   JSONB,
    p_id_comprobante_referencia  INTEGER DEFAULT NULL,
    p_id_tipo_registro           INTEGER DEFAULT NULL,
    p_id_categoria_gasto         INTEGER DEFAULT NULL,
    p_id_sucursal                INTEGER DEFAULT NULL,
    p_id_moneda                  INTEGER DEFAULT NULL,
    p_id_condicion_pago          INTEGER DEFAULT NULL,
    p_declarar_sunat             BOOLEAN DEFAULT FALSE,
    p_glosa                      VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria       INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_compra           INTEGER;
    v_id_detalle          INTEGER;
    v_item                INTEGER := 0;
    v_linea               JSONB;
    v_id_producto         INTEGER;
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
    v_importe             NUMERIC(12,4);
    v_total_bruto         NUMERIC(12,4) := 0;
    v_tasa_igv            NUMERIC(6,4) := 0.18;
    v_base_imponible      NUMERIC(12,4);
    v_igv_calculado       NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
    v_ref_estado          INTEGER;
    v_ref_serie           VARCHAR;
    v_ref_numero          VARCHAR;
    v_glosa_final         VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';
 
    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de la compra es obligatoria', 'registro', NULL);
    END IF;
 
    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;
 
    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;
 
    IF p_detalles IS NULL OR jsonb_typeof(p_detalles) IS DISTINCT FROM 'array' OR jsonb_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'La compra debe tener al menos una línea de detalle (arreglo JSON)', 'registro', NULL);
    END IF;
 
    -- Si se indica una compra de referencia, debe existir y estar ANULADA.
    -- Esto es lo que exige la regla de "corrección": no se puede referenciar
    -- una compra todavía activa (eso sería duplicar el stock).
    v_glosa_final := p_glosa;
    IF p_id_comprobante_referencia IS NOT NULL THEN
        SELECT estado, serie, numero INTO v_ref_estado, v_ref_serie, v_ref_numero
        FROM com_comprobante_compra
        WHERE id = p_id_comprobante_referencia;
 
        IF v_ref_estado IS NULL THEN
            RETURN json_build_object('error', 'La compra de referencia indicada no existe', 'registro', NULL);
        END IF;
 
        IF v_ref_estado <> 0 THEN
            RETURN json_build_object(
                'error', 'La compra de referencia debe estar anulada antes de registrar la corrección (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;
 
        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;
 
    -- IDs de listas resueltos una sola vez (no dentro del loop)
    SELECT glo.id INTO v_id_tipo_ingreso
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;
 
    SELECT glo.id INTO v_id_tipo_doc_ref
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;
 
    IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_ref IS NULL THEN
        RAISE EXCEPTION 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef) en gen_lista_opciones';
    END IF;
 
    -- Cabecera (totales en 0; se recalculan al final con lo realmente insertado)
    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_compra;
 
    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;
 
        v_id_producto := (v_linea->>'id_producto')::INTEGER;
        v_cantidad := (v_linea->>'cantidad')::NUMERIC;
        v_precio_unitario := COALESCE((v_linea->>'precio_unitario')::NUMERIC, 0);
        v_id_almacen_linea := COALESCE((v_linea->>'id_almacen')::INTEGER, p_id_almacen);
 
        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;
 
        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;
 
        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;
 
        SELECT afecta_stock INTO v_afecta_stock
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;
 
        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;
 
        v_importe := v_cantidad * v_precio_unitario;
        v_total_bruto := v_total_bruto + v_importe;
 
        v_descripcion_linea := v_linea->>'descripcion';
        IF v_descripcion_linea IS NULL THEN
            SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = v_id_producto;
        END IF;
 
        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
            id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
            afecta_stock, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_compra, v_item,
            (v_linea->>'id_clasificacion_gasto')::INTEGER,
            v_id_producto,
            v_descripcion_linea,
            (v_linea->>'id_unidad_medida')::INTEGER,
            v_id_almacen_linea,
            v_cantidad, v_precio_unitario, v_importe,
            v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_detalle;
 
        IF v_afecta_stock THEN
            v_result_movimiento := pro_crear_movimiento(
                p_fecha                 => p_fecha,
                p_id_producto           => v_id_producto,
                p_id_almacen            => v_id_almacen_linea,
                p_id_tipo_movimiento    => v_id_tipo_ingreso,
                p_cantidad              => v_cantidad,
                p_id_documento_ref      => v_id_detalle,
                p_id_tipo_documento_ref => v_id_tipo_doc_ref,
                p_glosa                 => 'Ingreso por compra ' || p_serie || '-' || p_numero,
                p_id_usuario_auditoria  => p_id_usuario_auditoria
            );
 
            IF (v_result_movimiento->>'error') IS NOT NULL THEN
                RAISE EXCEPTION '%', v_result_movimiento->>'error';
            END IF;
        END IF;
 
    END LOOP;
 
    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_id_compra
              AND afecta_stock = TRUE
              AND estado = 1
        )
    WHERE id = v_id_compra;

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;