CREATE OR REPLACE FUNCTION bal_listar_recargas_planta(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
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

    SELECT COUNT(*)
    INTO v_total
    FROM bal_recarga_planta rp
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
          OR gen_texto_coincide(COALESCE(rp.serie_guia_salida, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.numero_guia_salida, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(prv.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(prv.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            rp.id,
            rp.numero,
            rp.fecha_salida,
            rp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(prv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', prv.nombres, prv.apellido_paterno)), ''),
                prv.numero_documento
            ) AS nombre_proveedor,
            rp.id_almacen,
            a.nombre AS nombre_almacen,
            rp.id_guia_salida,
            rp.serie_guia_salida,
            rp.numero_guia_salida,
            rp.id_guia_retorno,
            rp.serie_guia_ingreso,
            rp.numero_guia_ingreso,
            rp.id_comprobante_compra,
            rp.serie_factura,
            rp.numero_factura,
            rp.fecha_llegada_almacen,
            rp.lote,
            rp.id_estado,
            est.nombre AS nombre_estado,
            est.descripcion AS descripcion_estado,
            (
                SELECT COUNT(*)::INT
                FROM bal_recarga_planta_detalle d
                WHERE d.id_recarga_planta = rp.id AND d.estado = 1
            ) AS total_cilindros,
            rp.observacion,
            rp.estado,
            rp.fecha_creacion,
            rp.fecha_modificacion
        FROM bal_recarga_planta rp
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
              OR gen_texto_coincide(COALESCE(rp.serie_guia_salida, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_guia_salida, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(prv.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(prv.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          )
        ORDER BY rp.fecha_salida DESC, rp.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
