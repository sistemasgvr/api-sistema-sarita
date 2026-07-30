CREATE OR REPLACE FUNCTION bal_listar_alquileres(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
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
    FROM bal_alquiler al
    WHERE al.estado = 1
      AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
      AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
      AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR LOWER(al.numero_alquiler) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(al.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            c.razon_social AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            al.estado,
            al.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = al.id AND ad.estado = 1
            ) AS total_detalles,
            (
                al.id_comprobante_venta IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_alquiler_detalle ad
                    WHERE ad.id_alquiler = al.id AND ad.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        WHERE al.estado = 1
          AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
          AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR LOWER(al.numero_alquiler) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(al.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY al.fecha_inicio DESC, al.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
