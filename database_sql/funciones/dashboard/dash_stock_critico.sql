-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_stock_critico
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_stock_critico(p_id_almacen integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_stock_critico(p_id_almacen integer DEFAULT NULL::integer, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_criticos BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total_criticos
    FROM pro_stock ps
    INNER JOIN pro_producto p ON ps.id_producto = p.id
    WHERE ps.estado = 1 
      AND p.estado = 1
      AND ps.stock <= ps.stock_minimo
      AND (p_id_almacen IS NULL OR ps.id_almacen = p_id_almacen);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            ps.id AS id_stock,
            ps.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS producto,
            p.marca,
            p.presentacion,
            sc.nombre AS subcategoria,
            cat.nombre AS categoria,
            a.nombre AS almacen,
            ps.stock AS stock_actual,
            ps.stock_minimo,
            (ps.stock_minimo - ps.stock) AS unidades_faltantes,
            CASE 
                WHEN ps.stock = 0 THEN 'AGOTADO'
                ELSE 'STOCK_CRITICO'
            END AS nivel_alerta,
            um.nombre AS unidad_medida
        FROM pro_stock ps
        INNER JOIN pro_producto p ON ps.id_producto = p.id
        INNER JOIN gen_almacen a ON ps.id_almacen = a.id
        LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
        LEFT JOIN pro_categoria cat ON sc.id_categoria = cat.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        WHERE ps.estado = 1 
          AND p.estado = 1
          AND ps.stock <= ps.stock_minimo
          AND (p_id_almacen IS NULL OR ps.id_almacen = p_id_almacen)
        ORDER BY ps.stock ASC, unidades_faltantes DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'totalStockCritico', v_total_criticos,
        'registros', v_registros
    );
END;
$function$;
