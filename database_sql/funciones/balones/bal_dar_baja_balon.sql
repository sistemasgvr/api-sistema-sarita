-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_dar_baja_balon
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_dar_baja_balon(p_id_balon integer, p_id_motivo_baja integer, p_id_usuario_solicita integer, p_id_usuario_autoriza integer, p_motivo_detalle character varying, p_id_cliente_comprador integer, p_id_comprobante_venta integer, p_serie_comprobante character varying, p_numero_comprobante character varying, p_monto_venta numeric, p_observacion character varying, p_fecha_baja date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_dar_baja_balon(p_id_balon integer, p_id_motivo_baja integer, p_id_usuario_solicita integer, p_id_usuario_autoriza integer DEFAULT NULL::integer, p_motivo_detalle character varying DEFAULT NULL::character varying, p_id_cliente_comprador integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_serie_comprobante character varying DEFAULT NULL::character varying, p_numero_comprobante character varying DEFAULT NULL::character varying, p_monto_venta numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_fecha_baja date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN bal_solicitar_baja_balon(
        p_id_balon,
        p_id_motivo_baja,
        p_id_usuario_solicita,
        p_motivo_detalle,
        p_id_cliente_comprador,
        p_id_comprobante_venta,
        p_serie_comprobante,
        p_numero_comprobante,
        p_monto_venta,
        p_observacion,
        p_fecha_baja,
        p_id_usuario_auditoria
    );
END;
$function$;
