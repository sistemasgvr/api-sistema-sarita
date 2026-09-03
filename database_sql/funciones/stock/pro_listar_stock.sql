-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_listar_stock
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS pro_listar_stock(p_busqueda character varying, p_limite integer, p_offset integer, p_id_almacen integer, p_id_producto integer, p_solo_bajo_minimo boolean, p_solo_activos integer);

CREATE OR REPLACE FUNCTION pro_listar_stock(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_almacen integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_solo_bajo_minimo boolean DEFAULT NULL::boolean, p_solo_activos integer DEFAULT 1)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Stock de productos: accesorios y, desde Fase 1, también gas (pro_stock unificado).
    SELECT
        COUNT(*),
        json_build_object(
            'total_items', COUNT(*),
            'bajo_minimo', COUNT(*) FILTER (WHERE s.stock <= s.stock_minimo),
            'ok', COUNT(*) FILTER (WHERE s.stock > s.stock_minimo),
            'stock_total', COALESCE(SUM(s.stock), 0)
        )
    INTO v_total, v_resumen
    FROM pro_stock s
    INNER JOIN gen_almacen a ON s.id_almacen = a.id
    INNER JOIN pro_producto p ON s.id_producto = p.id
    WHERE (p_solo_activos IS NULL OR s.estado = p_solo_activos)
      AND (p_solo_activos IS DISTINCT FROM 1 OR (a.estado = 1 AND p.estado = 1))
      AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
      AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
      AND (
          p_solo_bajo_minimo IS NULL
          OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
          OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
      )
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(a.nombre, p_busqueda)
          OR gen_texto_coincide(p.codigo, p_busqueda)
          OR gen_texto_coincide(p.nombre, p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.id_almacen,
            a.nombre AS nombre_almacen,
            a.id_sucursal,
            suc.nombre AS nombre_sucursal,
            s.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            sc.id AS id_sub_categoria,
            sc.nombre AS nombre_sub_categoria,
            cat.id AS id_categoria,
            cat.nombre AS nombre_categoria,
            s.stock,
            s.stock_minimo,
            (s.stock <= s.stock_minimo) AS bajo_minimo,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_stock s
        INNER JOIN gen_almacen a ON s.id_almacen = a.id
        INNER JOIN gen_sucursal suc ON a.id_sucursal = suc.id
        INNER JOIN pro_producto p ON s.id_producto = p.id
        LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
        LEFT JOIN pro_categoria cat ON sc.id_categoria = cat.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON s.id_usuario_modificacion = um2.id
        WHERE (p_solo_activos IS NULL OR s.estado = p_solo_activos)
          AND (p_solo_activos IS DISTINCT FROM 1 OR (a.estado = 1 AND p.estado = 1))
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
          AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
          AND (
              p_solo_bajo_minimo IS NULL
              OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
              OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
          )
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(a.nombre, p_busqueda)
              OR gen_texto_coincide(p.codigo, p_busqueda)
              OR gen_texto_coincide(p.nombre, p_busqueda)
          )
        ORDER BY a.nombre ASC, p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;
