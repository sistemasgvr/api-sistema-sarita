DROP FUNCTION IF EXISTS cli_listar_clientes_mapa(INT, VARCHAR, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION cli_listar_clientes_mapa(
    p_solo_activos    INT     DEFAULT 1,
    p_buscar          VARCHAR DEFAULT NULL,
    p_filtro_balones  VARCHAR DEFAULT NULL, -- NULL | CON_BALONES | PRESTADO_CLIENTE | ALQUILADO | EN_PODER_CLIENTE
    p_limite          INT     DEFAULT 500,
    p_offset          INT     DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_filtro    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');
    v_filtro := NULLIF(UPPER(TRIM(p_filtro_balones)), '');

    WITH balones_campo AS (
        SELECT
            x.id_cliente,
            x.id_balon,
            x.codigo_balon,
            x.numero_serie,
            x.nombre_estado_balon,
            x.nombre_tipo_balon,
            x.tipo_relacion,
            x.fecha_inicio,
            x.fecha_limite,
            x.dias_en_cliente,
            x.vencido,
            x.alerta_antiguedad
        FROM (
            SELECT
                COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) AS id_cliente,
                b.id AS id_balon,
                b.codigo_balon,
                b.numero_serie,
                eb.nombre AS nombre_estado_balon,
                tb.nombre AS nombre_tipo_balon,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN 'PRESTAMO'
                    WHEN 'ALQUILADO' THEN 'ALQUILER'
                    WHEN 'EN_PODER_CLIENTE' THEN 'PROPIO'
                    ELSE eb.nombre
                END AS tipo_relacion,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN COALESCE(prest.fecha_inicio, b.fecha_modificacion::date)
                    WHEN 'ALQUILADO' THEN COALESCE(alq.fecha_inicio, b.fecha_modificacion::date)
                    ELSE NULL
                END AS fecha_inicio,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_limite
                    WHEN 'ALQUILADO' THEN alq.fecha_limite
                    ELSE NULL
                END AS fecha_limite,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'ALQUILADO')
                         AND COALESCE(
                             CASE eb.nombre
                                 WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_inicio
                                 WHEN 'ALQUILADO' THEN alq.fecha_inicio
                             END,
                             b.fecha_modificacion::date
                         ) IS NOT NULL
                    THEN (
                        CURRENT_DATE - COALESCE(
                            CASE eb.nombre
                                WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_inicio
                                WHEN 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    )::INTEGER
                    ELSE NULL
                END AS dias_en_cliente,
                CASE
                    WHEN eb.nombre = 'ALQUILADO'
                         AND alq.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > alq.fecha_limite
                    THEN TRUE
                    WHEN eb.nombre = 'PRESTADO_CLIENTE'
                         AND prest.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > prest.fecha_limite
                    THEN TRUE
                    ELSE FALSE
                END AS vencido,
                CASE
                    WHEN eb.nombre NOT IN ('PRESTADO_CLIENTE', 'ALQUILADO') THEN NULL
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE eb.nombre
                                WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_inicio
                                WHEN 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 180 THEN 'CRITICO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE eb.nombre
                                WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_inicio
                                WHEN 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 90 THEN 'SEGUIMIENTO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE eb.nombre
                                WHEN 'PRESTADO_CLIENTE' THEN prest.fecha_inicio
                                WHEN 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 30 THEN 'ATENCION'
                    ELSE 'RECIENTE'
                END AS alerta_antiguedad
            FROM bal_balon b
            INNER JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
            LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(pd.fecha_prestamo, pd.fecha_entregado, pr.fecha_salida) AS fecha_inicio,
                    pd.fecha_vencimiento AS fecha_limite
                FROM bal_prestamo_detalle pd
                INNER JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
                WHERE pd.id_balon = b.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pr.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY pd.id DESC
                LIMIT 1
            ) prest ON TRUE
            LEFT JOIN LATERAL (
                SELECT
                    al.fecha_inicio,
                    al.fecha_fin_pactada AS fecha_limite
                FROM bal_alquiler_detalle ad
                INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
                WHERE ad.id_balon = b.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND al.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY ad.id DESC
                LIMIT 1
            ) alq ON TRUE
            WHERE b.estado = 1
              AND eb.nombre IN ('PRESTADO_CLIENTE', 'ALQUILADO', 'EN_PODER_CLIENTE')
              AND COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) IS NOT NULL
        ) x
    ),
    balones_agg AS (
        SELECT
            bc.id_cliente,
            json_agg(
                json_build_object(
                    'id_balon', bc.id_balon,
                    'codigo_balon', bc.codigo_balon,
                    'numero_serie', bc.numero_serie,
                    'nombre_estado_balon', bc.nombre_estado_balon,
                    'nombre_tipo_balon', bc.nombre_tipo_balon,
                    'tipo_relacion', bc.tipo_relacion,
                    'fecha_inicio', bc.fecha_inicio,
                    'fecha_limite', bc.fecha_limite,
                    'dias_en_cliente', bc.dias_en_cliente,
                    'vencido', bc.vencido,
                    'alerta_antiguedad', bc.alerta_antiguedad
                )
                ORDER BY
                    CASE WHEN bc.vencido THEN 0 ELSE 1 END,
                    bc.dias_en_cliente DESC NULLS LAST,
                    bc.codigo_balon
            ) AS balones,
            COUNT(*)::INT AS total_balones,
            BOOL_OR(bc.tipo_relacion = 'PRESTAMO') AS tiene_prestamo,
            BOOL_OR(bc.tipo_relacion = 'ALQUILER') AS tiene_alquiler,
            BOOL_OR(bc.tipo_relacion = 'PROPIO') AS tiene_propio,
            BOOL_OR(COALESCE(bc.vencido, FALSE)) AS tiene_vencidos,
            MAX(bc.dias_en_cliente) AS max_dias_en_cliente
        FROM (
            SELECT DISTINCT ON (id_cliente, id_balon)
                id_cliente,
                id_balon,
                codigo_balon,
                numero_serie,
                nombre_estado_balon,
                nombre_tipo_balon,
                tipo_relacion,
                fecha_inicio,
                fecha_limite,
                dias_en_cliente,
                vencido,
                alerta_antiguedad
            FROM balones_campo
            ORDER BY id_cliente, id_balon, tipo_relacion
        ) bc
        GROUP BY bc.id_cliente
    ),
    filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.numero_documento,
            tp.nombre AS nombre_tipo_persona,
            c.telefono,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            c.estado,
            COALESCE(ba.balones, '[]'::json) AS balones,
            COALESCE(ba.total_balones, 0) AS total_balones,
            COALESCE(ba.tiene_prestamo, FALSE) AS tiene_prestamo,
            COALESCE(ba.tiene_alquiler, FALSE) AS tiene_alquiler,
            COALESCE(ba.tiene_propio, FALSE) AS tiene_propio,
            COALESCE(ba.tiene_vencidos, FALSE) AS tiene_vencidos,
            ba.max_dias_en_cliente
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        INNER JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.es_principal = TRUE
              AND cd.estado = 1
              AND cd.latitud IS NOT NULL
              AND cd.longitud IS NOT NULL
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN balones_agg ba ON ba.id_cliente = c.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (
                v_buscar IS NULL
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR c.codigo_interno ILIKE '%' || v_buscar || '%'
                OR dir.direccion ILIKE '%' || v_buscar || '%'
              )
          AND (
                v_filtro IS NULL
                OR (v_filtro = 'CON_BALONES' AND COALESCE(ba.total_balones, 0) > 0)
                OR (v_filtro = 'PRESTADO_CLIENTE' AND COALESCE(ba.tiene_prestamo, FALSE))
                OR (v_filtro = 'ALQUILADO' AND COALESCE(ba.tiene_alquiler, FALSE))
                OR (v_filtro = 'EN_PODER_CLIENTE' AND COALESCE(ba.tiene_propio, FALSE))
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            CASE WHEN tiene_vencidos THEN 0 ELSE 1 END,
            total_balones DESC,
            razon_social NULLS LAST,
            nombres NULLS LAST,
            id DESC
        LIMIT GREATEST(COALESCE(p_limite, 500), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;
