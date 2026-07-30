CREATE OR REPLACE FUNCTION bal_listar_mantenimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_tipo_mantenimiento INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_es_externo BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_mantenimiento m
    INNER JOIN bal_balon b ON m.id_balon = b.id
    WHERE m.estado = 1
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_tipo_mantenimiento IS NULL OR m.id_tipo_mantenimiento = p_id_tipo_mantenimiento)
      AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
      AND (p_es_externo IS NULL OR m.es_externo = p_es_externo)
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(m.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_balon,
            b.codigo_balon,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(
                    TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)),
                    ''
                ),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            b.id_cliente_ubicacion,
            m.id_tipo_mantenimiento,
            tm.nombre AS nombre_tipo_mantenimiento,
            m.fecha_ingreso,
            m.fecha_salida,
            m.descripcion,
            m.costo,
            m.es_externo,
            m.id_estado,
            em.nombre AS nombre_estado,
            m.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            m.id_comprobante_compra,
            CASE
                WHEN cc.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cc.serie, cc.numero)
            END AS comprobante_compra,
            m.estado,
            m.fecha_creacion,
            (
                m.id_comprobante_venta IS NULL
                AND m.id_comprobante_compra IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_balon_ph_historial ph
                    WHERE ph.id_mantenimiento = m.id AND ph.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_mantenimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
        LEFT JOIN gen_lista_opciones em ON m.id_estado = em.id
        LEFT JOIN ven_comprobante cv ON m.id_comprobante_venta = cv.id
        LEFT JOIN com_comprobante_compra cc ON m.id_comprobante_compra = cc.id
        WHERE m.estado = 1
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_tipo_mantenimiento IS NULL OR m.id_tipo_mantenimiento = p_id_tipo_mantenimiento)
          AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
          AND (p_es_externo IS NULL OR m.es_externo = p_es_externo)
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(m.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY m.fecha_ingreso DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
