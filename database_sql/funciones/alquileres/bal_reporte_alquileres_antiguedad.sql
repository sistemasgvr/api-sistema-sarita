CREATE OR REPLACE FUNCTION bal_reporte_alquileres_antiguedad(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_rango_dias VARCHAR DEFAULT NULL,
    p_excluir_bajas BOOLEAN DEFAULT TRUE,
    p_solo_pendientes BOOLEAN DEFAULT TRUE
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
            ad.id AS id_detalle,
            a.id AS id_alquiler,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                c.razon_social,
                TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno))
            ) AS nombre_cliente,
            a.id_almacen,
            alm.nombre AS nombre_almacen,
            ad.id_balon,
            b.codigo_balon,
            b.numero_serie,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_planta,
            COALESCE(pl.razon_social, TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno))) AS nombre_planta,
            b.fecha_proxima_prueba_hidrostatica,
            b.mes_fabricacion,
            b.anio_fabricacion,
            eb.nombre AS nombre_estado_balon,
            a.fecha_inicio AS fecha_inicio_alquiler,
            a.fecha_fin_pactada,
            ad.fecha_devolucion,
            CASE
                WHEN ad.fecha_devolucion IS NOT NULL THEN NULL
                ELSE (CURRENT_DATE - a.fecha_inicio)::INTEGER
            END AS dias_en_alquiler,
            CASE
                WHEN ad.fecha_devolucion IS NOT NULL THEN 'DEVUELTO'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 180 THEN 'CRITICO_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 90 THEN 'SEGUIMIENTO_90_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 30 THEN 'ATENCION_30_90'
                ELSE 'RECIENTE_0_30'
            END AS rango_antiguedad
        FROM bal_alquiler_detalle ad
        INNER JOIN bal_alquiler a ON a.id = ad.id_alquiler AND a.estado = 1
        LEFT JOIN bal_balon b ON b.id = ad.id_balon
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN cli_clientes c ON a.id_cliente = c.id
        LEFT JOIN cli_clientes pl ON b.id_planta = pl.id
        LEFT JOIN gen_almacen alm ON a.id_almacen = alm.id
        WHERE ad.estado = 1
          AND (p_solo_pendientes = FALSE OR ad.fecha_devolucion IS NULL)
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_cliente IS NULL OR a.id_cliente = p_id_cliente)
          AND a.fecha_inicio IS NOT NULL
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(a.numero_alquiler, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.codigo_balon, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pg.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE (
            p_rango_dias IS NULL
            OR p_rango_dias = ''
            OR rango_antiguedad = p_rango_dias
        )
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM filtrado
                    ORDER BY
                        CASE WHEN dias_en_alquiler IS NULL THEN 1 ELSE 0 END,
                        dias_en_alquiler DESC NULLS LAST,
                        nombre_cliente ASC NULLS LAST,
                        codigo_balon ASC NULLS LAST
                    LIMIT p_limite
                    OFFSET p_offset
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total_pendientes', COUNT(*) FILTER (WHERE rango_antiguedad <> 'DEVUELTO'),
                    'reciente_0_30', COUNT(*) FILTER (WHERE rango_antiguedad = 'RECIENTE_0_30'),
                    'atencion_30_90', COUNT(*) FILTER (WHERE rango_antiguedad = 'ATENCION_30_90'),
                    'seguimiento_90_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'SEGUIMIENTO_90_180'),
                    'critico_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'CRITICO_180')
                )
                FROM base
            ) AS resumen
    )
    SELECT a.total, a.registros, a.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado a;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total_pendientes', 0,
                'reciente_0_30', 0,
                'atencion_30_90', 0,
                'seguimiento_90_180', 0,
                'critico_180', 0
            )
        )
    );
END;
$function$;
