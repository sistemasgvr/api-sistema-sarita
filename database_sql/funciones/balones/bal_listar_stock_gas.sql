-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_stock_gas
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
DROP FUNCTION IF EXISTS bal_listar_stock_gas(p_busqueda character varying, p_limite integer, p_offset integer, p_id_almacen integer, p_id_producto_gas integer);

CREATE OR REPLACE FUNCTION bal_listar_stock_gas(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_almacen integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH filtrado AS (
        SELECT
            p.id AS id_producto_gas,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            um.nombre AS nombre_unidad_medida,
            s.id_almacen,
            al.nombre AS nombre_almacen,
            COALESCE(s.stock, 0) AS capacidad_disponible,
            COALESCE(s.stock_minimo, 0) AS stock_minimo,
            (COALESCE(s.stock, 0) <= COALESCE(s.stock_minimo, 0)) AS bajo_minimo
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        INNER JOIN pro_stock s ON s.id_producto = p.id AND s.estado = 1
        INNER JOIN gen_almacen al ON al.id = s.id_almacen AND al.estado = 1
        WHERE p.estado = 1
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND (p_id_producto_gas IS NULL OR p.id = p_id_producto_gas)
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(al.nombre, ''), p_busqueda)
          )
    )
    SELECT
        (SELECT COUNT(*) FROM filtrado),
        (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
            FROM (
                SELECT *
                FROM filtrado
                ORDER BY
                    CASE WHEN capacidad_disponible > 0 THEN 0 ELSE 1 END,
                    nombre_producto ASC,
                    nombre_almacen ASC NULLS LAST
                LIMIT p_limite
                OFFSET p_offset
            ) t
        ),
        (
            SELECT json_build_object(
                'total_productos', COUNT(*),
                'capacidad_disponible', COALESCE(SUM(capacidad_disponible), 0),
                'bajo_minimo', COUNT(*) FILTER (WHERE bajo_minimo)
            )
            FROM filtrado
        )
    INTO v_total, v_registros, v_resumen;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;
