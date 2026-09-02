-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_movimientos
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.566Z
DROP FUNCTION IF EXISTS bal_listar_movimientos(p_busqueda character varying, p_limite integer, p_offset integer, p_id_balon integer, p_id_tipo_movimiento integer, p_id_cliente integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_movimientos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_balon integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_movimiento m
    INNER JOIN bal_balon b ON m.id_balon = b.id
    LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
    WHERE m.estado = 1
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_id_cliente IS NULL OR m.id_cliente = p_id_cliente)
      AND (p_fecha_desde IS NULL OR m.fecha_movimiento::DATE >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha_movimiento::DATE <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(m.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            COALESCE(
                m.id_cliente,
                mr.id_proveedor,
                rp.id_proveedor,
                mt.id_proveedor
            ) AS id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            m.id_almacen_origen,
            COALESCE(
                ao.nombre,
                CASE
                    WHEN tm.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
                    THEN 'Planta externa'
                    ELSE NULL
                END
            ) AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.fecha_movimiento,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            (
                m.id_documento_ref IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_baja_balon bb
                    WHERE bb.id_movimiento = m.id AND bb.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_movimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN bal_movimiento_recarga mr
            ON tdr.nombre = 'RECARGA'
           AND mr.id = m.id_documento_ref
        LEFT JOIN bal_recarga_planta rp
            ON tdr.nombre = 'RECARGA'
           AND rp.id = COALESCE(mr.id_recarga_planta, m.id_documento_ref)
        LEFT JOIN bal_mantenimiento mt
            ON tdr.nombre = 'MANTENIMIENTO'
           AND mt.id = m.id_documento_ref
        LEFT JOIN cli_clientes c ON c.id = COALESCE(
            m.id_cliente,
            mr.id_proveedor,
            rp.id_proveedor,
            mt.id_proveedor
        )
        LEFT JOIN gen_almacen ao ON m.id_almacen_origen = ao.id
        LEFT JOIN gen_almacen ad ON m.id_almacen_destino = ad.id
        WHERE m.estado = 1
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_id_cliente IS NULL OR m.id_cliente = p_id_cliente)
          AND (p_fecha_desde IS NULL OR m.fecha_movimiento::DATE >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha_movimiento::DATE <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(m.observacion, ''), p_busqueda)
          )
        ORDER BY m.fecha_movimiento DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
