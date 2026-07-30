CREATE OR REPLACE FUNCTION bal_listar_prestamo_detalles(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL
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
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
    LEFT JOIN bal_balon b ON pd.id_balon = b.id
    LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
    WHERE pd.estado = 1
      AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
      AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
      AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(b.codigo_balon, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pd.motivo_especifico, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            c.razon_social AS nombre_cliente,
            pd.id_producto,
            p.nombre AS nombre_producto,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.estado,
            pd.fecha_creacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        WHERE pd.estado = 1
          AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
          AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
          AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(b.codigo_balon, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pd.motivo_especifico, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY pd.fecha_prestamo DESC NULLS LAST, pd.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
