-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_listar_garantias
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_listar_garantias(p_busqueda character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_id_prestamo integer, p_id_estado integer, p_id_alquiler integer, p_estado_nombre character varying, p_desde date, p_hasta date);

CREATE OR REPLACE FUNCTION ven_listar_garantias(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_estado_nombre character varying DEFAULT NULL::character varying, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS json
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
    LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
    LEFT JOIN pro_producto p ON g.id_producto = p.id
    LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
    WHERE g.estado = 1
      AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
      AND (p_id_alquiler IS NULL OR g.id_alquiler = p_id_alquiler)
      AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
      AND (p_estado_nombre IS NULL OR eg.nombre = UPPER(TRIM(p_estado_nombre)))
      AND (p_desde IS NULL OR g.fecha_registro >= p_desde)
      AND (p_hasta IS NULL OR g.fecha_registro <= p_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(
              COALESCE(
                  NULLIF(TRIM(c.razon_social), ''),
                  NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                  ''
              ),
              p_busqueda
          )
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            al.numero_alquiler,
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
            g.id_medio_pago,
            mp.nombre AS medio_pago,
            g.fecha_reembolso,
            g.id_medio_reembolso,
            mr.nombre AS medio_reembolso,
            g.observacion_reembolso,
            g.estado,
            g.fecha_creacion,
            CASE
                WHEN g.id_prestamo IS NOT NULL THEN 'PRESTAMO'
                WHEN g.id_alquiler IS NOT NULL THEN 'ALQUILER'
                WHEN EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                ) THEN 'POS'
                ELSE 'MANUAL'
            END AS origen,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS es_manual,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND COALESCE(g.monto_devuelto, 0) = 0
                AND g.fecha_reembolso IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_editar,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_eliminar,
            (
                SELECT CASE
                    WHEN vc.id IS NULL THEN NULL
                    ELSE CONCAT_WS('-', vc.serie, vc.numero)
                END
                FROM ven_garantia_movimiento gm
                LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS comprobante_cobro,
            (
                SELECT gm.id_comprobante
                FROM ven_garantia_movimiento gm
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS id_comprobante_cobro
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_lista_opciones mp ON g.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones mr ON g.id_medio_reembolso = mr.id
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
          AND (p_id_alquiler IS NULL OR g.id_alquiler = p_id_alquiler)
          AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
          AND (p_estado_nombre IS NULL OR eg.nombre = UPPER(TRIM(p_estado_nombre)))
          AND (p_desde IS NULL OR g.fecha_registro >= p_desde)
          AND (p_hasta IS NULL OR g.fecha_registro <= p_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(
                  COALESCE(
                      NULLIF(TRIM(c.razon_social), ''),
                      NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                      ''
                  ),
                  p_busqueda
              )
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.observacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mp.nombre, ''), p_busqueda)
          )
        ORDER BY g.fecha_registro DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
