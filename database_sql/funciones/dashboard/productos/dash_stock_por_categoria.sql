-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_stock_por_categoria
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.657Z
DROP FUNCTION IF EXISTS dash_stock_por_categoria(p_id_almacen integer);

CREATE OR REPLACE FUNCTION dash_stock_por_categoria(p_id_almacen integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Mismo bug que dash_demanda_gases: dos sentencias separadas reutilizaban el CTE
    -- "valorizado", pero un WITH solo existe dentro de la sentencia que lo declara.
    -- La segunda sentencia fallaba con "relation valorizado does not exist".
    WITH valorizado AS (
        SELECT
            c.id AS id_categoria,
            COALESCE(c.nombre, 'Sin categoría') AS categoria,
            SUM(s.stock * p.precio_compra) AS valor
        FROM pro_stock s
        JOIN pro_producto p ON p.id = s.id_producto
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria c ON c.id = sc.id_categoria
        WHERE s.estado = 1
          AND p.estado = 1
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
        GROUP BY c.id, c.nombre
    ),
    totales AS (
        SELECT COALESCE(SUM(valor), 0) AS valor_total FROM valorizado
    )
    SELECT json_build_object(
        'valorTotal', (SELECT valor_total FROM totales),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idCategoria', v.id_categoria,
                'categoria', v.categoria,
                'valor', v.valor,
                'porcentaje', CASE WHEN t.valor_total > 0 THEN ROUND(v.valor / t.valor_total * 100, 2) ELSE 0 END
            )
            ORDER BY v.valor DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM valorizado v
    CROSS JOIN totales t;

    RETURN v_result;
END;
$function$
