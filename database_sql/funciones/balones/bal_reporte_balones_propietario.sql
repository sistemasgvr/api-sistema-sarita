-- CY6: conteos y detalle de cilindros por propietario (EMPRESA / PLANTA / CLIENTE).

CREATE OR REPLACE FUNCTION bal_reporte_balones_propietario(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_tipo_propietario VARCHAR DEFAULT NULL,
    p_id_planta INTEGER DEFAULT NULL,
    p_id_cliente_propietario INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_excluir_bajas BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_buscar VARCHAR;
    v_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(COALESCE(p_busqueda, '')), '');
    v_tipo := NULLIF(UPPER(TRIM(COALESCE(p_tipo_propietario, ''))), '');

    WITH base AS (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.id_propietario,
            UPPER(COALESCE(prop.nombre, '')) AS nombre_propietario,
            b.id_planta,
            COALESCE(
                NULLIF(TRIM(pl.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                pl.numero_documento
            ) AS nombre_planta,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            CASE UPPER(COALESCE(prop.nombre, ''))
                WHEN 'PLANTA' THEN COALESCE(
                    NULLIF(TRIM(pl.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                    pl.numero_documento,
                    'Sin proveedor'
                )
                WHEN 'CLIENTE' THEN COALESCE(
                    NULLIF(TRIM(cp.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                    cp.numero_documento,
                    'Sin cliente'
                )
                WHEN 'EMPRESA' THEN 'Empresa'
                ELSE COALESCE(prop.nombre, 'Sin propietario')
            END AS nombre_titular,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_estado_contenido,
            ec.nombre AS nombre_estado_contenido,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.fecha_proxima_prueba_hidrostatica
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN cli_clientes pl ON pl.id = b.id_planta
        LEFT JOIN cli_clientes cp ON cp.id = b.id_cliente_propietario
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
        LEFT JOIN pro_producto pg ON pg.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
        LEFT JOIN gen_almacen a ON a.id = b.id_almacen
        WHERE b.estado = 1
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
          AND (p_id_cliente_propietario IS NULL OR b.id_cliente_propietario = p_id_cliente_propietario)
          AND (
              v_tipo IS NULL
              OR UPPER(COALESCE(prop.nombre, '')) = v_tipo
          )
          AND (
              v_buscar IS NULL
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(prop.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(pl.razon_social, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(pl.nombres, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(cp.razon_social, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(cp.nombres, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), v_buscar)
          )
    ),
    universo AS (
        -- Conteos globales (sin filtro de tipo/titular) para las cards del resumen.
        SELECT
            b.id,
            UPPER(COALESCE(prop.nombre, '')) AS nombre_propietario,
            b.id_planta,
            COALESCE(
                NULLIF(TRIM(pl.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                pl.numero_documento,
                'Sin proveedor'
            ) AS nombre_planta,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento,
                'Sin cliente'
            ) AS nombre_cliente_propietario
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN cli_clientes pl ON pl.id = b.id_planta
        LEFT JOIN cli_clientes cp ON cp.id = b.id_cliente_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM base) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM base
                    ORDER BY
                        nombre_propietario ASC,
                        nombre_titular ASC NULLS LAST,
                        codigo_balon ASC NULLS LAST
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total', COUNT(*),
                    'empresa', COUNT(*) FILTER (WHERE nombre_propietario = 'EMPRESA'),
                    'planta', COUNT(*) FILTER (WHERE nombre_propietario = 'PLANTA'),
                    'cliente', COUNT(*) FILTER (WHERE nombre_propietario = 'CLIENTE'),
                    'otros', COUNT(*) FILTER (
                        WHERE nombre_propietario NOT IN ('EMPRESA', 'PLANTA', 'CLIENTE')
                           OR nombre_propietario = ''
                    ),
                    'por_planta', (
                        SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.cantidad DESC, p.nombre_planta), '[]'::JSON)
                        FROM (
                            SELECT
                                id_planta,
                                nombre_planta,
                                COUNT(*)::INT AS cantidad
                            FROM universo
                            WHERE nombre_propietario = 'PLANTA'
                            GROUP BY id_planta, nombre_planta
                        ) p
                    ),
                    'por_cliente', (
                        SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.cantidad DESC, c.nombre_cliente_propietario), '[]'::JSON)
                        FROM (
                            SELECT
                                id_cliente_propietario,
                                nombre_cliente_propietario,
                                COUNT(*)::INT AS cantidad
                            FROM universo
                            WHERE nombre_propietario = 'CLIENTE'
                            GROUP BY id_cliente_propietario, nombre_cliente_propietario
                        ) c
                    )
                )
                FROM universo
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
                'total', 0,
                'empresa', 0,
                'planta', 0,
                'cliente', 0,
                'otros', 0,
                'por_planta', '[]'::JSON,
                'por_cliente', '[]'::JSON
            )
        )
    );
END;
$function$;
