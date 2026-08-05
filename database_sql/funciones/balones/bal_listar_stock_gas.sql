-- Stock de gas físico = suma de residuales (capacidad_restante) de balones EMPRESA
-- LLENOS en EN_ALMACEN. Las recargas cliente descuentan ese residual.

CREATE OR REPLACE FUNCTION bal_listar_stock_gas(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_producto_gas INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH base AS (
        SELECT
            b.id_producto_gas,
            b.id_almacen,
            COALESCE(b.capacidad_restante, tb.capacidad, 0)::NUMERIC AS capacidad,
            COALESCE(ec.nombre, 'DESCONOCIDO') AS nombre_contenido,
            COALESCE(eb.nombre, '') AS nombre_estado_balon
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') = 'EMPRESA'
          AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
          AND b.id_producto_gas IS NOT NULL
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_producto_gas IS NULL OR b.id_producto_gas = p_id_producto_gas)
    ),
    agrupado AS (
        SELECT
            b.id_producto_gas,
            b.id_almacen,
            COUNT(*) FILTER (
                WHERE b.nombre_contenido = 'LLENO'
                  AND b.nombre_estado_balon = 'EN_ALMACEN'
            ) AS balones_llenos,
            COALESCE(SUM(b.capacidad) FILTER (
                WHERE b.nombre_contenido = 'LLENO'
                  AND b.nombre_estado_balon = 'EN_ALMACEN'
            ), 0) AS capacidad_disponible,
            COUNT(*) FILTER (
                WHERE b.nombre_contenido = 'VACIO'
                  AND b.nombre_estado_balon = 'EN_ALMACEN'
            ) AS balones_vacios,
            COUNT(*) FILTER (
                WHERE b.nombre_contenido = 'LLENO'
                  AND b.nombre_estado_balon <> 'EN_ALMACEN'
            ) AS balones_llenos_fuera
        FROM base b
        GROUP BY b.id_producto_gas, b.id_almacen
        HAVING
            COUNT(*) FILTER (
                WHERE b.nombre_contenido IN ('LLENO', 'VACIO')
                  AND b.nombre_estado_balon = 'EN_ALMACEN'
            ) > 0
            OR COUNT(*) FILTER (
                WHERE b.nombre_contenido = 'LLENO'
                  AND b.nombre_estado_balon <> 'EN_ALMACEN'
            ) > 0
    ),
    filtrado AS (
        SELECT
            g.id_producto_gas,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            um.nombre AS nombre_unidad_medida,
            g.id_almacen,
            a.nombre AS nombre_almacen,
            g.balones_llenos,
            g.capacidad_disponible,
            g.balones_vacios,
            g.balones_llenos_fuera,
            (g.balones_llenos > 0) AS tiene_stock_disponible
        FROM agrupado g
        INNER JOIN pro_producto p ON p.id = g.id_producto_gas
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN gen_almacen a ON a.id = g.id_almacen
        WHERE (
            p_busqueda = ''
            OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
            OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
            OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
        )
    )
    SELECT
        (SELECT COUNT(*) FROM filtrado),
        (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
            FROM (
                SELECT *
                FROM filtrado
                ORDER BY nombre_producto ASC, nombre_almacen ASC NULLS LAST
                LIMIT p_limite
                OFFSET p_offset
            ) t
        ),
        (
            SELECT json_build_object(
                'balones_llenos', COALESCE(SUM(balones_llenos), 0),
                'capacidad_disponible', COALESCE(SUM(capacidad_disponible), 0),
                'balones_vacios', COALESCE(SUM(balones_vacios), 0),
                'balones_llenos_fuera', COALESCE(SUM(balones_llenos_fuera), 0)
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
