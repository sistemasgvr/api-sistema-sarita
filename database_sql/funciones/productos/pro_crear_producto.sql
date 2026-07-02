CREATE OR REPLACE FUNCTION pro_crear_producto(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_id_sub_categoria INTEGER DEFAULT NULL,
    p_codigo_barra VARCHAR DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_marca VARCHAR DEFAULT NULL,
    p_presentacion VARCHAR DEFAULT NULL,
    p_es_gas BOOLEAN DEFAULT FALSE,
    p_es_servicio BOOLEAN DEFAULT FALSE,
    p_es_alquilable BOOLEAN DEFAULT FALSE,
    p_afecta_stock BOOLEAN DEFAULT TRUE,
    p_precio NUMERIC DEFAULT 0,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_codigo IS NULL OR TRIM(p_codigo) = '' THEN
        RETURN json_build_object('error', 'El código del producto es obligatorio', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre del producto es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo)) = LOWER(TRIM(p_codigo))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un producto con el código ' || TRIM(p_codigo), 'registro', NULL);
    END IF;

    IF p_id_sub_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_sub_categoria WHERE id = p_id_sub_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La subcategoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    INSERT INTO pro_producto (
        codigo,
        codigo_barra,
        nombre,
        id_sub_categoria,
        id_unidad_medida,
        marca,
        presentacion,
        es_gas,
        es_servicio,
        es_alquilable,
        afecta_stock,
        precio,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        TRIM(p_codigo),
        p_codigo_barra,
        TRIM(p_nombre),
        p_id_sub_categoria,
        p_id_unidad_medida,
        p_marca,
        p_presentacion,
        COALESCE(p_es_gas, FALSE),
        COALESCE(p_es_servicio, FALSE),
        COALESCE(p_es_alquilable, FALSE),
        COALESCE(p_afecta_stock, TRUE),
        COALESCE(p_precio, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_producto(v_id);
END;
$function$;
