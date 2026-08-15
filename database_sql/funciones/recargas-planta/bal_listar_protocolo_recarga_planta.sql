CREATE OR REPLACE FUNCTION bal_listar_protocolo_recarga_planta(
    p_busqueda VARCHAR DEFAULT '',
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Una fila por cilindro (detalle) con cabecera documental: ida, GRE, factura, retorno, lote.
    SELECT
        COUNT(*)::BIGINT,
        COALESCE(
            json_agg(row_to_json(t) ORDER BY t.fecha_salida DESC, t.id_recarga_planta DESC, t.codigo_balon),
            '[]'::JSON
        )
    INTO v_total, v_registros
    FROM (
        SELECT
            rp.id AS id_recarga_planta,
            rp.numero AS numero_orden,
            rp.fecha_salida,
            rp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(prv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', prv.nombres, prv.apellido_paterno)), ''),
                prv.numero_documento
            ) AS nombre_proveedor,
            rp.id_almacen,
            a.nombre AS nombre_almacen,
            rp.serie_guia_salida,
            rp.numero_guia_salida,
            rp.serie_guia_ingreso,
            rp.numero_guia_ingreso,
            rp.serie_factura,
            rp.numero_factura,
            rp.fecha_llegada_almacen,
            COALESCE(NULLIF(TRIM(det.lote), ''), NULLIF(TRIM(rp.lote), '')) AS lote,
            COALESCE(det.fecha_vencimiento_lote, rp.fecha_vencimiento_lote) AS fecha_vencimiento_lote,
            COALESCE(det.fecha_prueba_hidrostatica, rp.fecha_prueba_hidrostatica) AS fecha_prueba_hidrostatica,
            est.nombre AS nombre_estado,
            det.id AS id_detalle,
            det.id_balon,
            b.codigo_balon,
            det.id_producto,
            p.nombre AS nombre_producto,
            p.codigo AS codigo_producto,
            det.capacidad,
            um.nombre AS nombre_unidad_medida,
            det.observacion AS observacion_detalle,
            rp.observacion AS observacion_orden
        FROM bal_recarga_planta rp
        LEFT JOIN bal_recarga_planta_detalle det
            ON det.id_recarga_planta = rp.id AND det.estado = 1
        LEFT JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN pro_producto p ON p.id = det.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = det.id_unidad_medida
        LEFT JOIN cli_clientes prv ON prv.id = rp.id_proveedor
        LEFT JOIN gen_almacen a ON a.id = rp.id_almacen
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
        WHERE rp.estado = 1
          AND (p_id_proveedor IS NULL OR rp.id_proveedor = p_id_proveedor)
          AND (p_id_almacen IS NULL OR rp.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR rp.id_estado = p_id_estado)
          AND (p_fecha_desde IS NULL OR rp.fecha_salida >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR rp.fecha_salida <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(rp.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.lote, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(det.lote, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.serie_guia_salida, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_guia_salida, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.serie_guia_ingreso, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_guia_ingreso, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.serie_factura, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_factura, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(prv.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(prv.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          )
    ) t;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0)
    );
END;
$function$;
