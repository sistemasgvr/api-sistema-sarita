-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_alquileres
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.560Z
DROP FUNCTION IF EXISTS bal_listar_alquileres(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_id_almacen integer, p_id_estado integer);

CREATE OR REPLACE FUNCTION bal_listar_alquileres(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_alquiler al
    LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
    LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
    WHERE al.estado = 1
      AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
      AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
      AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
          OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
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
            al.id_producto_regulador,
            pr.codigo AS codigo_producto_regulador,
            pr.nombre AS nombre_producto_regulador,
            al.id_producto_stock,
            ps.codigo AS codigo_producto_stock,
            ps.nombre AS nombre_producto_stock,
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
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
        WHERE al.estado = 1
          AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
          AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
              OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
          )
        ORDER BY al.fecha_inicio DESC, al.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
