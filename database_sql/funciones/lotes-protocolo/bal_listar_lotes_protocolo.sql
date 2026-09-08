-- Function: bal_listar_lotes_protocolo
-- Fase 5 — fichas ICP de oxígeno medicinal (lote + protocolo).
DROP FUNCTION IF EXISTS bal_listar_lotes_protocolo(p_busqueda character varying, p_limite integer, p_offset integer, p_id_proveedor integer, p_id_producto_gas integer, p_vencidos boolean, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_lotes_protocolo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_vencidos boolean DEFAULT NULL::boolean, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
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
    FROM bal_lote_protocolo lp
    LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
    LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
    WHERE lp.estado = 1
      AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
      AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
      AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
      AND (
          p_vencidos IS NULL
          OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
          OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pv.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            lp.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            lp.descripcion_producto,
            lp.presentacion,
            lp.fecha_analisis,
            lp.fecha_emision,
            lp.fecha_fabricacion,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.tamano_lote_m3,
            lp.cantidad_envases,
            lp.valoracion_o2_pct,
            lp.cilindro_muestreado_serie,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            ar.nombre_original AS nombre_archivo_pdf,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1
            ) AS total_envases,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1 AND e.id_balon IS NOT NULL
            ) AS total_envases_vinculados,
            (
                SELECT COUNT(*)::INT
                FROM bal_balon b
                WHERE b.id_lote_protocolo_vigente = lp.id AND b.estado = 1
            ) AS total_balones_vigentes,
            lp.fecha_creacion,
            lp.fecha_modificacion
        FROM bal_lote_protocolo lp
        LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
        LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE lp.estado = 1
          AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
          AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
          AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
          AND (
              p_vencidos IS NULL
              OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
              OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pv.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
          )
        ORDER BY lp.fecha_emision DESC NULLS LAST, lp.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 10), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
