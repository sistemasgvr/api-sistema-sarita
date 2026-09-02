-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_actualizar_producto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.768Z
DROP FUNCTION IF EXISTS pro_actualizar_producto(p_id integer, p_codigo character varying, p_codigo_barra character varying, p_nombre character varying, p_id_sub_categoria integer, p_id_unidad_medida integer, p_marca character varying, p_presentacion character varying, p_es_gas boolean, p_es_servicio boolean, p_es_alquilable boolean, p_afecta_stock boolean, p_precio numeric, p_codigo_ubicacion character varying, p_id_usuario_auditoria integer, p_precio_compra numeric, p_precio_garantia numeric, p_factor_kg_m3 numeric, p_factor_lb_m3 numeric, p_es_mantenimiento boolean);

CREATE OR REPLACE FUNCTION pro_actualizar_producto(p_id integer, p_codigo character varying DEFAULT NULL::character varying, p_codigo_barra character varying DEFAULT NULL::character varying, p_nombre character varying DEFAULT NULL::character varying, p_id_sub_categoria integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_marca character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_es_gas boolean DEFAULT NULL::boolean, p_es_servicio boolean DEFAULT NULL::boolean, p_es_alquilable boolean DEFAULT NULL::boolean, p_afecta_stock boolean DEFAULT NULL::boolean, p_precio numeric DEFAULT NULL::numeric, p_codigo_ubicacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_precio_compra numeric DEFAULT NULL::numeric, p_precio_garantia numeric DEFAULT NULL::numeric, p_factor_kg_m3 numeric DEFAULT NULL::numeric, p_factor_lb_m3 numeric DEFAULT NULL::numeric, p_es_mantenimiento boolean DEFAULT NULL::boolean)
 RETURNS json
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

    IF p_factor_kg_m3 IS NOT NULL AND p_factor_kg_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor kg→m³ debe ser mayor a 0', 'registro', NULL);
    END IF;

    IF p_factor_lb_m3 IS NOT NULL AND p_factor_lb_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor lb→m³ debe ser mayor a 0', 'registro', NULL);
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
        es_mantenimiento = CASE
            WHEN COALESCE(p_es_servicio, es_servicio)
                 AND NOT COALESCE(p_es_gas, es_gas)
                 AND NOT v_es_alquilable
            THEN COALESCE(p_es_mantenimiento, es_mantenimiento)
            ELSE FALSE
        END,
        afecta_stock = CASE
            WHEN COALESCE(p_es_gas, es_gas) OR COALESCE(p_es_servicio, es_servicio) THEN FALSE
            ELSE COALESCE(p_afecta_stock, afecta_stock)
        END,
        precio = COALESCE(p_precio, precio),
        precio_compra = COALESCE(p_precio_compra, precio_compra),
        precio_garantia = COALESCE(p_precio_garantia, precio_garantia),
        factor_kg_m3 = CASE
            WHEN COALESCE(p_es_gas, es_gas) THEN COALESCE(p_factor_kg_m3, factor_kg_m3)
            ELSE NULL
        END,
        factor_lb_m3 = CASE
            WHEN COALESCE(p_es_gas, es_gas) THEN COALESCE(p_factor_lb_m3, factor_lb_m3)
            ELSE NULL
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    PERFORM pro_asegurar_stock_producto(p_id, p_id_usuario_auditoria);

    RETURN pro_obtener_producto(p_id);
END;
$function$
