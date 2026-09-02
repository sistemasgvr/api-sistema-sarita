-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_recargas_planta
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.574Z
DROP FUNCTION IF EXISTS bal_listar_recargas_planta(p_busqueda character varying, p_limite integer, p_offset integer, p_id_proveedor integer, p_id_almacen integer, p_id_estado integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_recargas_planta(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
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
    LEFT JOIN gre_guia_remision gs ON gs.id = rp.id_guia_salida AND gs.estado = 1
    LEFT JOIN gre_guia_remision gi ON gi.id = rp.id_guia_retorno AND gi.estado = 1
    LEFT JOIN com_comprobante_compra cc ON cc.id = rp.id_comprobante_compra AND cc.estado = 1
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
          OR gen_texto_coincide(COALESCE(rp.serie_guia_salida, gs.serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.numero_guia_salida, gs.numero, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.serie_guia_ingreso, gi.serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.numero_guia_ingreso, gi.numero, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.serie_factura, cc.serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(rp.numero_factura, cc.numero, ''), p_busqueda)
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
            COALESCE(rp.serie_guia_salida, gs.serie) AS serie_guia_salida,
            COALESCE(rp.numero_guia_salida, gs.numero) AS numero_guia_salida,
            rp.id_guia_retorno,
            COALESCE(rp.serie_guia_ingreso, gi.serie) AS serie_guia_ingreso,
            COALESCE(rp.numero_guia_ingreso, gi.numero) AS numero_guia_ingreso,
            rp.id_comprobante_compra,
            COALESCE(rp.serie_factura, cc.serie) AS serie_factura,
            COALESCE(rp.numero_factura, cc.numero) AS numero_factura,
            rp.fecha_llegada_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
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
            rp.fecha_modificacion,
            (
                CASE
                    WHEN COALESCE(est.nombre, '') IN ('RETORNADO', 'CERRADO') THEN FALSE
                    WHEN rp.id_comprobante_compra IS NOT NULL THEN FALSE
                    WHEN EXISTS (
                        SELECT 1
                        FROM com_comprobante_compra c
                        WHERE c.id_recarga_planta = rp.id AND c.estado = 1
                    ) THEN FALSE
                    ELSE TRUE
                END
            ) AS puede_eliminar,
            (
                CASE
                    WHEN rp.id_comprobante_compra IS NOT NULL
                      OR EXISTS (
                          SELECT 1
                          FROM com_comprobante_compra c
                          WHERE c.id_recarga_planta = rp.id AND c.estado = 1
                      ) THEN 'tiene compra'
                    WHEN COALESCE(est.nombre, '') IN ('RETORNADO', 'CERRADO') THEN 'estado no permite'
                    ELSE NULL
                END
            ) AS motivo_bloqueo_eliminar
        FROM bal_recarga_planta rp
        LEFT JOIN cli_clientes prv ON prv.id = rp.id_proveedor
        LEFT JOIN gen_almacen a ON a.id = rp.id_almacen
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
        LEFT JOIN gre_guia_remision gs ON gs.id = rp.id_guia_salida AND gs.estado = 1
        LEFT JOIN gre_guia_remision gi ON gi.id = rp.id_guia_retorno AND gi.estado = 1
        LEFT JOIN com_comprobante_compra cc ON cc.id = rp.id_comprobante_compra AND cc.estado = 1
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
              OR gen_texto_coincide(COALESCE(rp.serie_guia_salida, gs.serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_guia_salida, gs.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.serie_guia_ingreso, gi.serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_guia_ingreso, gi.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.serie_factura, cc.serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(rp.numero_factura, cc.numero, ''), p_busqueda)
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
$function$
