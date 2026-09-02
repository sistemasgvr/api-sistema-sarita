-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_almacenes_operativos
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.642Z
DROP FUNCTION IF EXISTS dash_almacenes_operativos(p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_almacenes_operativos(p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_almacenes BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total_almacenes
    FROM gen_almacen
    WHERE estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            a.id AS id_almacen,
            a.nombre AS almacen,
            s.nombre AS sucursal,
            a.ubicacion,
            COALESCE(d.nombre, '—') AS distrito,
            COALESCE(prov.nombre, '—') AS provincia,
            (
                SELECT COUNT(*) 
                FROM pro_stock ps 
                WHERE ps.id_almacen = a.id AND ps.estado = 1 AND ps.stock > 0
            ) AS total_items_con_stock
        FROM gen_almacen a
        INNER JOIN gen_sucursal s ON a.id_sucursal = s.id
        LEFT JOIN gen_distrito d ON a.id_distrito = d.id
        LEFT JOIN gen_provincia prov ON a.id_provincia = prov.id
        WHERE a.estado = 1
        ORDER BY a.id ASC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'totalAlmacenesOperativos', v_total_almacenes,
        'registros', v_registros
    );
END;
$function$
