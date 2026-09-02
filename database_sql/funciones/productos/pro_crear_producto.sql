-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_crear_producto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.773Z
DROP FUNCTION IF EXISTS pro_crear_producto(p_codigo character varying, p_nombre character varying, p_id_sub_categoria integer, p_codigo_barra character varying, p_id_unidad_medida integer, p_marca character varying, p_presentacion character varying, p_es_gas boolean, p_es_servicio boolean, p_es_alquilable boolean, p_afecta_stock boolean, p_precio numeric, p_codigo_ubicacion character varying, p_id_usuario_auditoria integer, p_precio_compra numeric, p_precio_garantia numeric, p_factor_kg_m3 numeric, p_factor_lb_m3 numeric, p_es_mantenimiento boolean);

CREATE OR REPLACE FUNCTION pro_crear_producto(p_codigo character varying, p_nombre character varying, p_id_sub_categoria integer DEFAULT NULL::integer, p_codigo_barra character varying DEFAULT NULL::character varying, p_id_unidad_medida integer DEFAULT NULL::integer, p_marca character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_es_gas boolean DEFAULT false, p_es_servicio boolean DEFAULT false, p_es_alquilable boolean DEFAULT false, p_afecta_stock boolean DEFAULT true, p_precio numeric DEFAULT 0, p_codigo_ubicacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_precio_compra numeric DEFAULT 0, p_precio_garantia numeric DEFAULT 0, p_factor_kg_m3 numeric DEFAULT NULL::numeric, p_factor_lb_m3 numeric DEFAULT NULL::numeric, p_es_mantenimiento boolean DEFAULT false)
 RETURNS json
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
$function$
