CREATE OR REPLACE FUNCTION bal_listar_prestamos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_prestamo INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
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
    FROM bal_prestamo pr
    LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
    WHERE pr.estado = 1
      AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
      AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.titulo, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pr.id,
            pr.numero_prestamo,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            c.razon_social AS nombre_cliente,
            pr.fecha_salida,
            pr.fecha_retorno_pactada,
            pr.fecha_retorno_real,
            pr.titulo,
            pr.id_estado,
            ep.nombre AS nombre_estado,
            pr.estado,
            pr.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = pr.id AND pd.estado = 1
            ) AS total_detalles
        FROM bal_prestamo pr
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ep ON pr.id_estado = ep.id
        WHERE pr.estado = 1
          AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
          AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.titulo, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY pr.fecha_salida DESC NULLS LAST, pr.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
