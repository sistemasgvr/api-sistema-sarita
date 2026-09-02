-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_prestamo_detalles
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.570Z
DROP FUNCTION IF EXISTS bal_listar_prestamo_detalles(p_busqueda character varying, p_limite integer, p_offset integer, p_id_prestamo integer, p_id_balon integer, p_id_estado integer);

CREATE OR REPLACE FUNCTION bal_listar_prestamo_detalles(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_prestamo integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
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
          OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
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
            pr.id_almacen,
            a.nombre AS nombre_almacen,
            pd.id_producto,
            COALESCE(pg.nombre, p.nombre) AS nombre_producto,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            eb.nombre AS nombre_estado_balon,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_guia_entrega,
            pd.serie_guia_entrega,
            pd.numero_guia_entrega,
            pd.id_guia_devolucion,
            pd.serie_guia_devolucion,
            pd.numero_guia_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.estado,
            pd.fecha_creacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_almacen a ON pr.id_almacen = a.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        WHERE pd.estado = 1
          AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
          AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
          AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY pd.fecha_prestamo DESC NULLS LAST, pd.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
