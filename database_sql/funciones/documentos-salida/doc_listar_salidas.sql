-- Function: doc_listar_salidas
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · p_id_proveedor: filtra órdenes de planta por proveedor (el selector de
--     Compras solo debe ofrecer las del proveedor de la factura);
--   · p_codigo_estado_ciclo: uno o varios códigos de EstadoCicloSalida
--     separados por coma (p. ej. 'GENERADA,EMITIDA_SUNAT') para excluir
--     borradores/anuladas sin resolver ids en el cliente;
--   · total_cilindros / total_productos: total_items mezclaba líneas de balón
--     y de gas y se mostraba como "N cilindros".
--   Ambos parámetros van al final: las llamadas posicionales no cambian.
--
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   retorno_fisico: el listado de recargas marcaba "RETORNADO" con solo
--   fecha_llegada_almacen, que no implica que los cilindros hayan entrado.

DROP FUNCTION IF EXISTS doc_listar_salidas(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_orden integer, p_id_estado_ciclo integer, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_emitido_sunat boolean, p_fecha_desde date, p_fecha_hasta date, p_codigo_tipo_orden character varying);
DROP FUNCTION IF EXISTS doc_listar_salidas(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_orden integer, p_id_estado_ciclo integer, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_emitido_sunat boolean, p_fecha_desde date, p_fecha_hasta date, p_codigo_tipo_orden character varying, p_sin_actividad_vigente boolean);

CREATE OR REPLACE FUNCTION doc_listar_salidas(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_id_tipo_orden integer DEFAULT NULL::integer,
    p_id_estado_ciclo integer DEFAULT NULL::integer,
    p_id_sucursal integer DEFAULT NULL::integer,
    p_id_almacen integer DEFAULT NULL::integer,
    p_id_cliente integer DEFAULT NULL::integer,
    p_emitido_sunat boolean DEFAULT NULL::boolean,
    p_fecha_desde date DEFAULT NULL::date,
    p_fecha_hasta date DEFAULT NULL::date,
    p_codigo_tipo_orden character varying DEFAULT NULL::character varying,
    p_sin_actividad_vigente boolean DEFAULT NULL::boolean,
    p_id_proveedor integer DEFAULT NULL::integer,
    p_codigo_estado_ciclo character varying DEFAULT NULL::character varying
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_estados_ciclo TEXT[];
BEGIN
    SET TIME ZONE 'America/Lima';

    -- 'GENERADA,EMITIDA_SUNAT' -> {GENERADA,EMITIDA_SUNAT}; vacío = sin filtro.
    IF NULLIF(TRIM(COALESCE(p_codigo_estado_ciclo, '')), '') IS NOT NULL THEN
        SELECT array_agg(UPPER(TRIM(x))) FILTER (WHERE TRIM(x) <> '')
        INTO v_estados_ciclo
        FROM unnest(string_to_array(p_codigo_estado_ciclo, ',')) AS x;
    END IF;

    SELECT COUNT(*),
           json_build_object(
               'total', COUNT(*),
               'borrador', COUNT(*) FILTER (WHERE ec.nombre = 'BORRADOR'),
               'generada', COUNT(*) FILTER (WHERE ec.nombre = 'GENERADA'),
               'emitida_sunat', COUNT(*) FILTER (WHERE ec.nombre = 'EMITIDA_SUNAT'),
               'anulada', COUNT(*) FILTER (WHERE ec.nombre = 'ANULADA')
           )
    INTO v_total, v_resumen
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
    WHERE d.estado = 1
      AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
      AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
      AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
      AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
      AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
      AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
      AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
      AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
      AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
      AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
      AND (
          p_sin_actividad_vigente IS NOT TRUE
          OR (
              ec.nombre NOT IN ('BORRADOR', 'ANULADA')
              AND NOT EXISTS (
                  SELECT 1
                  FROM age_actividad a
                  LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                  WHERE a.id_doc_salida = d.id
                    AND a.estado = 1
                    AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
              )
          )
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cli.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id, d.numero,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.fecha, d.fecha_traslado, d.fecha_llegada_almacen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            d.id_almacen_destino, almdest.nombre AS nombre_almacen_destino,
            d.id_almacen_retorno, almret.nombre AS nombre_almacen_retorno,
            -- Retorno físico: los envases de la orden tienen su entrada
            -- vigente. La fecha de llegada sola no mueve inventario.
            EXISTS (
                SELECT 1
                FROM inv_movimiento m
                JOIN doc_salida_detalle ddr ON ddr.id = m.id_documento_detalle
                JOIN gen_lista_opciones tmv ON tmv.id = m.id_tipo_movimiento
                JOIN gen_lista ltmv ON ltmv.id = tmv.id_lista
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND ltmv.nombre = 'TipoMovInvUnificado'
                  AND tmv.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND ddr.id_doc_salida = d.id
                  AND ddr.id_balon IS NOT NULL
                  AND m.id_balon = ddr.id_balon
            ) AS retorno_fisico,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            d.id_comprobante_compra,
            d.lote, d.observaciones,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            CASE
                WHEN d.id_venta IS NOT NULL THEN (
                    SELECT COUNT(*) FROM ven_comprobante_detalle vd
                    WHERE vd.id_comprobante = d.id_venta AND (vd.estado = 1 OR vc.estado = 0)
                )
                ELSE (
                    SELECT COUNT(*) FROM doc_salida_detalle dd
                    WHERE dd.id_doc_salida = d.id AND dd.estado = 1
                )
            END AS total_items,
            -- Solo líneas propias: en órdenes desde venta el detalle vive en la venta.
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NOT NULL
            ) AS total_cilindros,
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NULL
            ) AS total_productos,
            d.fecha_creacion
        FROM doc_salida d
        JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN gen_almacen almret ON almret.id = d.id_almacen_retorno
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        WHERE d.estado = 1
          AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
          AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
          AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
          AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
          AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
          AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
          AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
          AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
          AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
          AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
          AND (
              p_sin_actividad_vigente IS NOT TRUE
              OR (
                  ec.nombre NOT IN ('BORRADOR', 'ANULADA')
                  AND NOT EXISTS (
                      SELECT 1
                      FROM age_actividad a
                      LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                      WHERE a.id_doc_salida = d.id
                        AND a.estado = 1
                        AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
                  )
              )
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cli.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
          )
        ORDER BY d.fecha DESC, d.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total, 'resumen', v_resumen);
END;
$function$;

