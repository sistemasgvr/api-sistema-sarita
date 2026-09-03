-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_convertir_a_unidad_producto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_convertir_a_unidad_producto(p_id_producto integer, p_cantidad numeric, p_id_unidad_origen integer);

CREATE OR REPLACE FUNCTION inv_convertir_a_unidad_producto(p_id_producto integer, p_cantidad numeric, p_id_unidad_origen integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_unidad_producto VARCHAR;
    v_unidad_origen VARCHAR;
    v_factor_kg NUMERIC;
    v_factor_lb NUMERIC;
    v_nombre_producto VARCHAR;
    v_m3 NUMERIC;
BEGIN
    IF p_id_producto IS NULL OR p_cantidad IS NULL OR p_id_unidad_origen IS NULL THEN
        RETURN p_cantidad;
    END IF;

    SELECT
        p.nombre,
        UPPER(TRIM(COALESCE(um.nombre, ''))),
        p.factor_kg_m3,
        p.factor_lb_m3
    INTO v_nombre_producto, v_unidad_producto, v_factor_kg, v_factor_lb
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto;

    IF NOT FOUND THEN
        RETURN p_cantidad;
    END IF;

    SELECT UPPER(TRIM(COALESCE(nombre, '')))
    INTO v_unidad_origen
    FROM gen_lista_opciones
    WHERE id = p_id_unidad_origen;

    -- Alias: KGM es kilogramo en el catálogo SUNAT.
    v_unidad_producto := CASE WHEN v_unidad_producto IN ('KGM') THEN 'KG' ELSE v_unidad_producto END;
    v_unidad_origen := CASE WHEN v_unidad_origen IN ('KGM') THEN 'KG' ELSE v_unidad_origen END;
    v_unidad_producto := CASE WHEN v_unidad_producto IN ('M3') THEN 'MT3' ELSE v_unidad_producto END;
    v_unidad_origen := CASE WHEN v_unidad_origen IN ('M3') THEN 'MT3' ELSE v_unidad_origen END;

    -- Sin unidad de destino conocida, o misma unidad: no hay nada que convertir.
    IF v_unidad_producto = '' OR v_unidad_origen = '' OR v_unidad_producto = v_unidad_origen THEN
        RETURN p_cantidad;
    END IF;

    -- Paso 1: unidad origen -> m³
    IF v_unidad_origen = 'MT3' THEN
        v_m3 := p_cantidad;
    ELSIF v_unidad_origen = 'KG' THEN
        IF COALESCE(v_factor_kg, 0) <= 0 THEN
            RAISE EXCEPTION
                'El producto % no tiene factor_kg_m3 configurado; no se puede convertir % KG a %',
                COALESCE(v_nombre_producto, '#' || p_id_producto), p_cantidad, v_unidad_producto;
        END IF;
        v_m3 := p_cantidad * v_factor_kg;
    ELSIF v_unidad_origen = 'LB' THEN
        IF COALESCE(v_factor_lb, 0) <= 0 THEN
            RAISE EXCEPTION
                'El producto % no tiene factor_lb_m3 configurado; no se puede convertir % LB a %',
                COALESCE(v_nombre_producto, '#' || p_id_producto), p_cantidad, v_unidad_producto;
        END IF;
        v_m3 := p_cantidad * v_factor_lb;
    ELSE
        RAISE EXCEPTION
            'No se puede convertir de % a % para el producto %: unidad de origen no soportada',
            v_unidad_origen, v_unidad_producto, COALESCE(v_nombre_producto, '#' || p_id_producto);
    END IF;

    -- Paso 2: m³ -> unidad del producto
    IF v_unidad_producto = 'MT3' THEN
        RETURN ROUND(v_m3, 4);
    ELSIF v_unidad_producto = 'KG' THEN
        IF COALESCE(v_factor_kg, 0) <= 0 THEN
            RAISE EXCEPTION
                'El producto % no tiene factor_kg_m3 configurado; no se puede convertir % % a KG',
                COALESCE(v_nombre_producto, '#' || p_id_producto), p_cantidad, v_unidad_origen;
        END IF;
        RETURN ROUND(v_m3 / v_factor_kg, 4);
    ELSIF v_unidad_producto = 'LB' THEN
        IF COALESCE(v_factor_lb, 0) <= 0 THEN
            RAISE EXCEPTION
                'El producto % no tiene factor_lb_m3 configurado; no se puede convertir % % a LB',
                COALESCE(v_nombre_producto, '#' || p_id_producto), p_cantidad, v_unidad_origen;
        END IF;
        RETURN ROUND(v_m3 / v_factor_lb, 4);
    END IF;

    RAISE EXCEPTION
        'No se puede convertir de % a % para el producto %: unidad de destino no soportada',
        v_unidad_origen, v_unidad_producto, COALESCE(v_nombre_producto, '#' || p_id_producto);
END;
$function$;
