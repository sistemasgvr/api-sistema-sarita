-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_clientes_mora
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS dash_clientes_mora(p_dias_urgente integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION dash_clientes_mora(p_dias_urgente integer DEFAULT 30, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_cobrar INT;
    v_result         JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    WITH mora AS (
        SELECT
            c.id AS id_cliente,
            COALESCE(c.razon_social, c.nombres) AS cliente,
            SUM(fc.monto_saldo) AS monto_vencido,
            MAX(CURRENT_DATE - fc.fecha_vencimiento) AS dias_retraso_max
        FROM fin_cuenta fc
        JOIN cli_clientes c ON c.id = fc.id_tercero
        WHERE fc.estado = 1
          AND fc.id_tipo_cuenta = v_id_tipo_cobrar
          AND fc.monto_saldo > 0
          AND fc.fecha_vencimiento IS NOT NULL
          AND fc.fecha_vencimiento < CURRENT_DATE
          AND (p_fecha_desde IS NULL OR fc.fecha_emision >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR fc.fecha_emision <= p_fecha_hasta)
        GROUP BY c.id, c.razon_social, c.nombres
    )
    SELECT json_build_object(
        'cantidadDeudoresMora', COUNT(*),
        'cantidadUrgentes', COUNT(*) FILTER (WHERE dias_retraso_max > p_dias_urgente),
        'diasUrgente', p_dias_urgente,
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idCliente', id_cliente,
                'cliente', cliente,
                'montoVencido', monto_vencido,
                'diasRetraso', dias_retraso_max,
                'urgente', dias_retraso_max > p_dias_urgente
            )
            ORDER BY dias_retraso_max DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM mora;

    RETURN v_result;
END;
$function$;
