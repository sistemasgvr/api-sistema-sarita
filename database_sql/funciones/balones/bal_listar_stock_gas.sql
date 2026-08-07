-- Stock de gas físico = residuales de balones EMPRESA en EN_ALMACEN con gas útil
-- (LLENO o DESCONOCIDO/parcial con capacidad_restante > 0).
-- Lista todos los productos gas del catálogo (aunque el stock sea 0).

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

    WITH gases AS (
        SELECT
            p.id AS id_producto_gas,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            um.nombre AS nombre_unidad_medida
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.estado = 1
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND (p_id_producto_gas IS NULL OR p.id = p_id_producto_gas)
    ),
    base AS (
        SELECT
            b.id_producto_gas,
            b.id_almacen,
            COALESCE(ec.nombre, 'DESCONOCIDO') AS nombre_contenido,
            COALESCE(eb.nombre, '') AS nombre_estado_balon,
            CASE
                WHEN COALESCE(ec.nombre, 'DESCONOCIDO') = 'VACIO' THEN 0::NUMERIC
                WHEN COALESCE(ec.nombre, 'DESCONOCIDO') = 'LLENO'
                    THEN COALESCE(b.capacidad_restante, tb.capacidad, 0)::NUMERIC
                -- Parcial / desconocido: solo cuenta lo medido al recojo/devolución
                ELSE COALESCE(b.capacidad_restante, 0)::NUMERIC
            END AS capacidad
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
                WHERE b.nombre_estado_balon = 'EN_ALMACEN'
                  AND b.capacidad > 0
            ) AS balones_llenos,
            COALESCE(SUM(b.capacidad) FILTER (
                WHERE b.nombre_estado_balon = 'EN_ALMACEN'
                  AND b.capacidad > 0
            ), 0) AS capacidad_disponible,
            COUNT(*) FILTER (
                WHERE b.nombre_contenido = 'VACIO'
                  AND b.nombre_estado_balon = 'EN_ALMACEN'
            ) AS balones_vacios,
            COUNT(*) FILTER (
                WHERE b.capacidad > 0
                  AND b.nombre_estado_balon <> 'EN_ALMACEN'
            ) AS balones_llenos_fuera
        FROM base b
        GROUP BY b.id_producto_gas, b.id_almacen
    ),
    -- Una fila por gas+almacén con movimiento; si no hay balones, una fila con ceros.
    expandido AS (
        SELECT
            g.id_producto_gas,
            g.codigo_producto,
            g.nombre_producto,
            g.nombre_unidad_medida,
            a.id_almacen,
            a.balones_llenos,
            a.capacidad_disponible,
            a.balones_vacios,
            a.balones_llenos_fuera,
            (a.balones_llenos > 0) AS tiene_stock_disponible
        FROM gases g
        INNER JOIN agrupado a ON a.id_producto_gas = g.id_producto_gas
        WHERE p_id_almacen IS NULL OR a.id_almacen = p_id_almacen

        UNION ALL

        SELECT
            g.id_producto_gas,
            g.codigo_producto,
            g.nombre_producto,
            g.nombre_unidad_medida,
            NULL::INTEGER AS id_almacen,
            0::BIGINT AS balones_llenos,
            0::NUMERIC AS capacidad_disponible,
            0::BIGINT AS balones_vacios,
            0::BIGINT AS balones_llenos_fuera,
            FALSE AS tiene_stock_disponible
        FROM gases g
        WHERE NOT EXISTS (
            SELECT 1 FROM agrupado a WHERE a.id_producto_gas = g.id_producto_gas
        )
          AND p_id_almacen IS NULL
    ),
    filtrado AS (
        SELECT
            e.id_producto_gas,
            e.codigo_producto,
            e.nombre_producto,
            e.nombre_unidad_medida,
            e.id_almacen,
            al.nombre AS nombre_almacen,
            e.balones_llenos,
            e.capacidad_disponible,
            e.balones_vacios,
            e.balones_llenos_fuera,
            e.tiene_stock_disponible
        FROM expandido e
        LEFT JOIN gen_almacen al ON al.id = e.id_almacen
        WHERE (
            p_busqueda = ''
            OR gen_texto_coincide(COALESCE(e.codigo_producto, ''), p_busqueda)
            OR gen_texto_coincide(COALESCE(e.nombre_producto, ''), p_busqueda)
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
