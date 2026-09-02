-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_listar_resumen_diario
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.810Z
DROP FUNCTION IF EXISTS ven_listar_resumen_diario(p_busqueda character varying, p_limite integer, p_offset integer, p_id_estado_sunat integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION ven_listar_resumen_diario(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_estado_sunat integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM ven_resumen_diario r
    WHERE r.estado = 1
      AND (p_id_estado_sunat IS NULL OR r.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(r.identificador, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.ticket_sunat, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.correlativo, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.correlativo,
            r.identificador,
            r.ticket_sunat,
            r.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            r.moneda,
            r.cantidad_docs,
            r.total_importe,
            r.total_igv,
            r.total_valor_venta,
            r.fecha_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM ven_resumen_diario r
        LEFT JOIN gen_lista_opciones es ON r.id_estado_sunat = es.id
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        WHERE r.estado = 1
          AND (p_id_estado_sunat IS NULL OR r.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(r.identificador, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.ticket_sunat, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.correlativo, ''), p_busqueda)
          )
        ORDER BY r.fecha DESC, r.correlativo DESC, r.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
