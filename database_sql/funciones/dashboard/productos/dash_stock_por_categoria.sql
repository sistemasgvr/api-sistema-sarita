DROP FUNCTION IF EXISTS dash_stock_por_categoria(INT);

CREATE OR REPLACE FUNCTION dash_stock_por_categoria(
    p_id_almacen INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_valor_total NUMERIC(14,2);
    v_result      JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

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
    )
    SELECT COALESCE(SUM(valor), 0) INTO v_valor_total FROM valorizado;

    SELECT json_build_object(
        'valorTotal', v_valor_total,
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idCategoria', id_categoria,
                'categoria', categoria,
                'valor', valor,
                'porcentaje', CASE WHEN v_valor_total > 0 THEN ROUND(valor / v_valor_total * 100, 2) ELSE 0 END
            )
            ORDER BY valor DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM valorizado;

    RETURN v_result;
END;
$$;
