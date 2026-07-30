-- Resumen (KPIs) de cuentas por cobrar o por pagar: pendiente, vencido, cantidades.

DROP FUNCTION IF EXISTS fin_resumen_cuentas(VARCHAR);

CREATE OR REPLACE FUNCTION fin_resumen_cuentas(
    p_tipo VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
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
            fc.id_tercero,
            COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) AS saldo,
            fc.fecha_vencimiento
        FROM fin_cuenta fc
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
    )
    SELECT json_build_object(
        'totalPendiente',   COALESCE(SUM(saldo) FILTER (WHERE saldo > 0), 0),
        'cantidadCuentas',  COUNT(*) FILTER (WHERE saldo > 0),
        'totalVencido',     COALESCE(SUM(saldo) FILTER (WHERE saldo > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento < CURRENT_DATE), 0),
        'cantidadVencidas', COUNT(*) FILTER (WHERE saldo > 0 AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento < CURRENT_DATE),
        'cantidadTerceros', COUNT(DISTINCT id_tercero) FILTER (WHERE saldo > 0)
    ) INTO v_res
    FROM c;

    RETURN v_res;
END;
$$;
