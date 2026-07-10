CREATE OR REPLACE FUNCTION ven_listar_comprobantes(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_comprobante INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_serie VARCHAR DEFAULT NULL
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
    FROM ven_comprobante c
    LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
    WHERE c.estado = 1
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
      AND (
          p_busqueda = ''
          OR LOWER(c.serie) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(c.numero) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cl.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cl.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.total_importe,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            c.estado,
            c.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS total_detalles
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        WHERE c.estado = 1
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
          AND (
              p_busqueda = ''
              OR LOWER(c.serie) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(c.numero) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cl.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cl.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
