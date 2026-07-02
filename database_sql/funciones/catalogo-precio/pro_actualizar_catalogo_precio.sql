CREATE OR REPLACE FUNCTION pro_actualizar_catalogo_precio(
    p_id INTEGER,
    p_id_tipo_catalogo INTEGER DEFAULT NULL,
    p_periodo VARCHAR DEFAULT NULL,
    p_nombre_item VARCHAR DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_tipo_balon INTEGER DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_clasificacion VARCHAR DEFAULT NULL,
    p_modelo VARCHAR DEFAULT NULL,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_descripcion_presentacion VARCHAR DEFAULT NULL,
    p_costo_producto NUMERIC DEFAULT NULL,
    p_costo_flete NUMERIC DEFAULT NULL,
    p_porcentaje_margen NUMERIC DEFAULT NULL,
    p_precio_final NUMERIC DEFAULT NULL,
    p_precio_garantia NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_item VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre_item := NULLIF(TRIM(p_nombre_item), '');

    IF p_id_tipo_catalogo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_catalogo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de catálogo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_tipo_balon IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_tipo_balon WHERE id = p_id_tipo_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_proveedor IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE pro_catalogo_precio
    SET
        id_tipo_catalogo = COALESCE(p_id_tipo_catalogo, id_tipo_catalogo),
        periodo = COALESCE(p_periodo, periodo),
        nombre_item = COALESCE(v_nombre_item, nombre_item),
        id_producto = COALESCE(p_id_producto, id_producto),
        id_tipo_balon = COALESCE(p_id_tipo_balon, id_tipo_balon),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        clasificacion = COALESCE(p_clasificacion, clasificacion),
        modelo = COALESCE(p_modelo, modelo),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        descripcion_presentacion = COALESCE(p_descripcion_presentacion, descripcion_presentacion),
        costo_producto = COALESCE(p_costo_producto, costo_producto),
        costo_flete = COALESCE(p_costo_flete, costo_flete),
        porcentaje_margen = COALESCE(p_porcentaje_margen, porcentaje_margen),
        precio_final = COALESCE(p_precio_final, precio_final),
        precio_garantia = COALESCE(p_precio_garantia, precio_garantia),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_catalogo_precio(p_id);
END;
$function$;
