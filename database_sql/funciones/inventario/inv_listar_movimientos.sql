DROP FUNCTION IF EXISTS public.inv_listar_movimientos (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_naturaleza character varying,
  p_id_producto integer,
  p_id_balon integer,
  p_id_almacen integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_documento_origen integer,
  p_id_documento_origen integer,
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_cliente integer
);

CREATE OR REPLACE FUNCTION public.inv_listar_movimientos (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_naturaleza character varying DEFAULT NULL::character varying,
  p_id_producto integer DEFAULT NULL::integer,
  p_id_balon integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_documento_origen integer DEFAULT NULL::integer,
  p_id_documento_origen integer DEFAULT NULL::integer,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_buscar VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_busqueda), '');

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
    LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
    LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
    LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
    LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
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
          p_id_cliente IS NULL
          OR (p_id_cliente = -1 AND m.id_cliente IS NULL)
          OR m.id_cliente = p_id_cliente
      )
      AND (
          v_buscar IS NULL
          OR gen_texto_coincide(cli_texto_busqueda(cli), v_buscar)
          OR gen_texto_coincide(COALESCE(m.glosa, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(p.codigo, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(ao.nombre, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(ad.nombre, ''), v_buscar)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), v_buscar)
      );

    -- El documento origen se resuelve después del LIMIT: solo para las filas de la página.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
      SELECT
          pagina.*,
          doc.codigo_documento_origen,
          doc.importe_linea,
          doc.total_documento,
          doc.moneda_documento
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
            CASE
                WHEN m.naturaleza = 'BALON' THEN COALESCE(tb.nombre, cat.nombre)
                ELSE cat.nombre
            END AS nombre_tipo_producto,
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
            cli.numero_documento AS numero_documento_cliente,
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
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria cat ON cat.id = sc.id_categoria
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
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
              p_id_cliente IS NULL
              OR (p_id_cliente = -1 AND m.id_cliente IS NULL)
              OR m.id_cliente = p_id_cliente
          )
          AND (
              v_buscar IS NULL
              OR gen_texto_coincide(cli_texto_busqueda(cli), v_buscar)
              OR gen_texto_coincide(COALESCE(m.glosa, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(p.codigo, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(ao.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(ad.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), v_buscar)
          )
        ORDER BY m.fecha::DATE DESC, m.fecha_creacion DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
      ) pagina
      LEFT JOIN LATERAL inv_resumen_documento_origen(
          pagina.nombre_tipo_documento_origen,
          pagina.id_documento_origen,
          pagina.naturaleza,
          pagina.id_documento_detalle,
          pagina.id_producto,
          pagina.id_balon
      ) doc ON TRUE
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;
