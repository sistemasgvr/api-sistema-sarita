-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_listar_movimientos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_listar_movimientos(p_busqueda character varying, p_limite integer, p_offset integer, p_naturaleza character varying, p_id_producto integer, p_id_balon integer, p_id_almacen integer, p_id_tipo_movimiento integer, p_id_tipo_documento_origen integer, p_id_documento_origen integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION inv_listar_movimientos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_naturaleza character varying DEFAULT NULL::character varying, p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_tipo_documento_origen integer DEFAULT NULL::integer, p_id_documento_origen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'producto', COUNT(*) FILTER (WHERE m.naturaleza = 'PRODUCTO'),
            'balon', COUNT(*) FILTER (WHERE m.naturaleza = 'BALON'),
            'salidas', COUNT(*) FILTER (WHERE COALESCE(inv_signo_tipo_movimiento(m.id_tipo_movimiento), 0) < 0),
            'entradas', COUNT(*) FILTER (WHERE COALESCE(inv_signo_tipo_movimiento(m.id_tipo_movimiento), 0) > 0)
        )
    INTO v_total, v_resumen
    FROM inv_movimiento m
    LEFT JOIN pro_producto p ON p.id = m.id_producto
    LEFT JOIN bal_balon b ON b.id = m.id_balon
    LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
    LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
    WHERE m.estado = 1
      AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
      AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
      AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
      AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.naturaleza,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            m.id_balon,
            b.numero_serie AS numero_serie_balon,
            m.cantidad,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_cliente,
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), ''),
                cli.numero_documento
            ) AS nombre_cliente,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_origen,
            m.id_tipo_documento_origen,
            tdo.nombre AS nombre_tipo_documento_origen,
            m.id_documento_detalle,
            m.id_movimiento_padre,
            (m.id_documento_origen IS NULL) AS puede_anular,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM inv_movimiento m
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
        LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
        LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        LEFT JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        LEFT JOIN auth_usuarios uc ON uc.id = m.id_usuario_creacion
        WHERE m.estado = 1
          AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
          AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
          AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
          AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
          )
        ORDER BY m.fecha DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;
