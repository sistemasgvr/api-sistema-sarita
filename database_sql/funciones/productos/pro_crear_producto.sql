DROP FUNCTION IF EXISTS pro_crear_producto(VARCHAR, VARCHAR, INTEGER, VARCHAR, INTEGER, VARCHAR, VARCHAR, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, NUMERIC, VARCHAR, INTEGER, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS pro_crear_producto(VARCHAR, VARCHAR, INTEGER, VARCHAR, INTEGER, VARCHAR, VARCHAR, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, NUMERIC, VARCHAR, INTEGER, NUMERIC, NUMERIC, NUMERIC, NUMERIC);

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
    p_codigo_ubicacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_precio_compra NUMERIC DEFAULT 0,
    p_precio_garantia NUMERIC DEFAULT 0,
    p_factor_kg_m3 NUMERIC DEFAULT NULL,
    p_factor_lb_m3 NUMERIC DEFAULT NULL,
    p_es_mantenimiento BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_codigo_ubicacion VARCHAR;
    v_es_alquilable BOOLEAN;
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

    v_codigo_ubicacion := NULLIF(TRIM(p_codigo_ubicacion), '');
    v_es_alquilable := COALESCE(p_es_alquilable, FALSE);

    IF v_codigo_ubicacion IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo_ubicacion)) = LOWER(v_codigo_ubicacion)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un producto con el código de ubicación ' || v_codigo_ubicacion,
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

    IF p_factor_kg_m3 IS NOT NULL AND p_factor_kg_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor kg→m³ debe ser mayor a 0', 'registro', NULL);
    END IF;

    IF p_factor_lb_m3 IS NOT NULL AND p_factor_lb_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor lb→m³ debe ser mayor a 0', 'registro', NULL);
    END IF;

    INSERT INTO pro_producto (
        codigo,
        codigo_barra,
        codigo_ubicacion,
        nombre,
        id_sub_categoria,
        id_unidad_medida,
        marca,
        presentacion,
        es_gas,
        es_servicio,
        es_alquilable,
        es_mantenimiento,
        afecta_stock,
        precio,
        precio_compra,
        precio_garantia,
        factor_kg_m3,
        factor_lb_m3,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        TRIM(p_codigo),
        p_codigo_barra,
        v_codigo_ubicacion,
        TRIM(p_nombre),
        p_id_sub_categoria,
        p_id_unidad_medida,
        p_marca,
        p_presentacion,
        COALESCE(p_es_gas, FALSE),
        COALESCE(p_es_servicio, FALSE),
        v_es_alquilable,
        CASE
            WHEN COALESCE(p_es_servicio, FALSE)
                 AND NOT COALESCE(p_es_gas, FALSE)
                 AND NOT v_es_alquilable
            THEN COALESCE(p_es_mantenimiento, FALSE)
            ELSE FALSE
        END,
        CASE
            WHEN COALESCE(p_es_gas, FALSE) OR COALESCE(p_es_servicio, FALSE) THEN FALSE
            ELSE COALESCE(p_afecta_stock, TRUE)
        END,
        COALESCE(p_precio, 0),
        COALESCE(p_precio_compra, 0),
        COALESCE(p_precio_garantia, 0),
        CASE WHEN COALESCE(p_es_gas, FALSE) THEN p_factor_kg_m3 ELSE NULL END,
        CASE WHEN COALESCE(p_es_gas, FALSE) THEN p_factor_lb_m3 ELSE NULL END,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM pro_asegurar_stock_producto(v_id, p_id_usuario_auditoria);

    RETURN pro_obtener_producto(v_id);
END;
$function$;
