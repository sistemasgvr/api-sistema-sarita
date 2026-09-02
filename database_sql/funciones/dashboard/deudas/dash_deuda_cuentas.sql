-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_deuda_cuentas
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.650Z
DROP FUNCTION IF EXISTS dash_deuda_cuentas(p_tipo character varying, p_id_cliente integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION dash_deuda_cuentas(p_tipo character varying, p_id_cliente integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo INT;
    v_res     JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;
    WITH c AS (
        SELECT
            COALESCE(fc.id_tercero::text, fc.tercero_nombre) AS tercero_key,
            COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) AS saldo,
            COALESCE(fc.monto_abonado, 0) AS abonado,
            fc.fecha_vencimiento
        FROM fin_cuenta fc
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND fc.numero_cuotas_total IS NULL
          AND (p_id_cliente IS NULL OR fc.id_tercero = p_id_cliente)
          AND (p_fecha_desde IS NULL OR fc.fecha_emision >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR fc.fecha_emision <= p_fecha_hasta)
    )
    SELECT json_build_object(
        'totalPendiente',   COALESCE(SUM(saldo) FILTER (WHERE saldo > 0), 0),
        'cantidadCuentas',  COUNT(*) FILTER (WHERE saldo > 0),
        'totalVencido',     COALESCE(SUM(saldo) FILTER (WHERE saldo > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento < CURRENT_DATE), 0),
        'cantidadVencidas', COUNT(*) FILTER (WHERE saldo > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento < CURRENT_DATE),
        'cantidadTerceros', COUNT(DISTINCT tercero_key) FILTER (WHERE saldo > 0),
        'totalCobrado',     COALESCE(SUM(abonado) FILTER (WHERE UPPER(p_tipo) = 'COBRAR'), 0),
        'totalPagado',      COALESCE(SUM(abonado) FILTER (WHERE UPPER(p_tipo) = 'PAGAR'), 0)
    ) INTO v_res
    FROM c;

    RETURN v_res;
END;
$function$
