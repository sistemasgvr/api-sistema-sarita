-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_listar_stock_bajo_notificar
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS pro_listar_stock_bajo_notificar();

CREATE OR REPLACE FUNCTION pro_listar_stock_bajo_notificar()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.es_cero DESC, t.nombre_almacen, t.nombre_producto), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', s.id,
            'id_almacen', s.id_almacen,
            'nombre_almacen', a.nombre,
            'id_producto', s.id_producto,
            'codigo_producto', p.codigo,
            'nombre_producto', p.nombre,
            'stock', s.stock,
            'stock_minimo', s.stock_minimo,
            'es_cero', (s.stock <= 0)
        ) AS row_data,
        a.nombre AS nombre_almacen,
        p.nombre AS nombre_producto,
        (s.stock <= 0) AS es_cero
        FROM pro_stock s
        INNER JOIN gen_almacen a ON a.id = s.id_almacen AND a.estado = 1
        INNER JOIN pro_producto p ON p.id = s.id_producto AND p.estado = 1
        WHERE s.estado = 1
          AND COALESCE(p.afecta_stock, TRUE) = TRUE
          AND s.stock <= COALESCE(s.stock_minimo, 0)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
