DROP FUNCTION IF EXISTS com_actualizar_compra;

CREATE OR REPLACE FUNCTION com_actualizar_compra(
    p_id INTEGER,
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_serie VARCHAR DEFAULT NULL,
    p_numero VARCHAR DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_tipo_registro INTEGER DEFAULT NULL,
    p_id_categoria_gasto INTEGER DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_moneda INTEGER DEFAULT NULL,
    p_id_condicion_pago INTEGER DEFAULT NULL,
    p_sub_total NUMERIC DEFAULT NULL,
    p_igv NUMERIC DEFAULT NULL,
    p_total_importe NUMERIC DEFAULT NULL,
    p_afecta_inventario BOOLEAN DEFAULT NULL,
    p_declarar_sunat BOOLEAN DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_serie IS NOT NULL AND p_numero IS NOT NULL AND p_id_proveedor IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM com_comprobante_compra
            WHERE id_proveedor = p_id_proveedor
              AND serie = p_serie
              AND numero = p_numero
              AND id <> p_id
              AND estado = 1
        ) THEN
            RAISE EXCEPTION 'Ya existe otro comprobante con esa serie y número para este proveedor.';
        END IF;
    END IF;

    UPDATE com_comprobante_compra
    SET
        id_tipo_comprobante = COALESCE(p_id_tipo_comprobante, id_tipo_comprobante),
        serie               = COALESCE(p_serie, serie),
        numero              = COALESCE(p_numero, numero),
        fecha               = COALESCE(p_fecha, fecha),
        id_proveedor        = COALESCE(p_id_proveedor, id_proveedor),
        id_tipo_registro     = COALESCE(p_id_tipo_registro, id_tipo_registro),
        id_categoria_gasto   = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        id_sucursal         = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen          = COALESCE(p_id_almacen, id_almacen),
        id_moneda           = COALESCE(p_id_moneda, id_moneda),
        id_condicion_pago    = COALESCE(p_id_condicion_pago, id_condicion_pago),
        sub_total           = COALESCE(p_sub_total, sub_total),
        igv                 = COALESCE(p_igv, igv),
        total_importe       = COALESCE(p_total_importe, total_importe),
        afecta_inventario   = COALESCE(p_afecta_inventario, afecta_inventario),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        glosa               = COALESCE(p_glosa, glosa),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN com_obtener_compra(p_id);
END;
$function$;