CREATE OR REPLACE FUNCTION pro_actualizar_producto(
    p_id INTEGER,
    p_codigo VARCHAR DEFAULT NULL,
    p_codigo_barra VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_id_sub_categoria INTEGER DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_marca VARCHAR DEFAULT NULL,
    p_presentacion VARCHAR DEFAULT NULL,
    p_es_gas BOOLEAN DEFAULT NULL,
    p_es_servicio BOOLEAN DEFAULT NULL,
    p_es_alquilable BOOLEAN DEFAULT NULL,
    p_afecta_stock BOOLEAN DEFAULT NULL,
    p_precio NUMERIC DEFAULT NULL,
    p_codigo_ubicacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_precio_compra NUMERIC DEFAULT NULL,
    p_precio_garantia NUMERIC DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR;
    v_nombre VARCHAR;
    v_codigo_ubicacion VARCHAR;
    v_es_alquilable BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := NULLIF(TRIM(p_codigo), '');
    v_nombre := NULLIF(TRIM(p_nombre), '');
    v_codigo_ubicacion := CASE
        WHEN p_codigo_ubicacion IS NULL THEN NULL
        ELSE NULLIF(TRIM(p_codigo_ubicacion), '')
    END;

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo)) = LOWER(v_codigo)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro producto con el código ' || v_codigo, 'registro', NULL);
    END IF;

    IF p_codigo_ubicacion IS NOT NULL
       AND v_codigo_ubicacion IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM pro_producto
           WHERE LOWER(TRIM(codigo_ubicacion)) = LOWER(v_codigo_ubicacion)
             AND id <> p_id
       ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otro producto con el código de ubicación ' || v_codigo_ubicacion,
            'registro', NULL
        );
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

    SELECT COALESCE(p_es_alquilable, es_alquilable)
    INTO v_es_alquilable
    FROM pro_producto
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE pro_producto
    SET
        codigo = COALESCE(v_codigo, codigo),
        codigo_barra = COALESCE(p_codigo_barra, codigo_barra),
        codigo_ubicacion = CASE
            WHEN p_codigo_ubicacion IS NULL THEN codigo_ubicacion
            ELSE v_codigo_ubicacion
        END,
        nombre = COALESCE(v_nombre, nombre),
        id_sub_categoria = COALESCE(p_id_sub_categoria, id_sub_categoria),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        marca = COALESCE(p_marca, marca),
        presentacion = COALESCE(p_presentacion, presentacion),
        es_gas = COALESCE(p_es_gas, es_gas),
        es_servicio = COALESCE(p_es_servicio, es_servicio),
        es_alquilable = v_es_alquilable,
        afecta_stock = COALESCE(p_afecta_stock, afecta_stock),
        precio = COALESCE(p_precio, precio),
        precio_compra = COALESCE(p_precio_compra, precio_compra),
        precio_garantia = CASE
            WHEN NOT v_es_alquilable THEN 0
            WHEN p_precio_garantia IS NULL THEN precio_garantia
            ELSE p_precio_garantia
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN pro_obtener_producto(p_id);
END;
$function$;
