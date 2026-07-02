CREATE OR REPLACE FUNCTION pro_crear_catalogo_precio(
    p_id_tipo_catalogo INTEGER,
    p_nombre_item VARCHAR,
    p_periodo VARCHAR DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_tipo_balon INTEGER DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_clasificacion VARCHAR DEFAULT NULL,
    p_modelo VARCHAR DEFAULT NULL,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_descripcion_presentacion VARCHAR DEFAULT NULL,
    p_costo_producto NUMERIC DEFAULT 0,
    p_costo_flete NUMERIC DEFAULT 0,
    p_porcentaje_margen NUMERIC DEFAULT NULL,
    p_precio_final NUMERIC DEFAULT NULL,
    p_precio_garantia NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre_item IS NULL OR TRIM(p_nombre_item) = '' THEN
        RETURN json_build_object('error', 'El nombre del ítem es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
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

    INSERT INTO pro_catalogo_precio (
        id_tipo_catalogo,
        periodo,
        nombre_item,
        id_producto,
        id_tipo_balon,
        id_proveedor,
        clasificacion,
        modelo,
        capacidad,
        id_unidad_medida,
        descripcion_presentacion,
        costo_producto,
        costo_flete,
        porcentaje_margen,
        precio_final,
        precio_garantia,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_catalogo,
        p_periodo,
        TRIM(p_nombre_item),
        p_id_producto,
        p_id_tipo_balon,
        p_id_proveedor,
        p_clasificacion,
        p_modelo,
        p_capacidad,
        p_id_unidad_medida,
        p_descripcion_presentacion,
        COALESCE(p_costo_producto, 0),
        COALESCE(p_costo_flete, 0),
        p_porcentaje_margen,
        p_precio_final,
        p_precio_garantia,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_catalogo_precio(v_id);
END;
$function$;
