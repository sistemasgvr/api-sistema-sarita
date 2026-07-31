CREATE OR REPLACE FUNCTION ven_listar_garantias(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
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
    FROM ven_garantia g
    LEFT JOIN cli_clientes c ON g.id_cliente = c.id
    LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
    LEFT JOIN pro_producto p ON g.id_producto = p.id
    WHERE g.estado = 1
      AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
      AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            c.razon_social AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            g.cantidad_venta,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.estado,
            g.fecha_creacion
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
          AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
          )
        ORDER BY g.fecha_registro DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
