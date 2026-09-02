-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_monto_mora
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.654Z
DROP FUNCTION IF EXISTS dash_monto_mora(p_fecha date, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_monto_mora(p_fecha date DEFAULT CURRENT_DATE, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_monto_mora_total NUMERIC(12,4) := 0;
    v_total_deudores BIGINT := 0;
    v_id_tipo_cobrar INTEGER;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones
    WHERE LOWER(nombre) LIKE '%cobrar%' OR LOWER(nombre) LIKE '%cliente%'
    LIMIT 1;

    SELECT COALESCE(SUM(monto_saldo), 0), COUNT(*)
    INTO v_monto_mora_total, v_total_deudores
    FROM fin_cuenta
    WHERE estado = 1 
      AND monto_saldo > 0 
      AND fecha_vencimiento < p_fecha
      AND (v_id_tipo_cobrar IS NULL OR id_tipo_cuenta = v_id_tipo_cobrar);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            fc.id,
            COALESCE(c.razon_social, CONCAT(c.nombres, ' ', c.apellido_paterno)) AS cliente,
            c.telefono,
            CONCAT(vc.serie, '-', vc.numero) AS comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            (p_fecha - fc.fecha_vencimiento) AS dias_mora,
            fc.monto_pendiente,
            fc.monto_abonado,
            fc.monto_saldo
        FROM fin_cuenta fc
        INNER JOIN cli_clientes c ON fc.id_tercero = c.id
        LEFT JOIN ven_comprobante vc ON fc.id_comprobante_venta = vc.id
        WHERE fc.estado = 1 
          AND fc.monto_saldo > 0 
          AND fc.fecha_vencimiento < p_fecha
          AND (v_id_tipo_cobrar IS NULL OR fc.id_tipo_cuenta = v_id_tipo_cobrar)
        ORDER BY dias_mora DESC, fc.monto_saldo DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'montoMoraTotal', v_monto_mora_total,
        'totalDeudores', v_total_deudores,
        'registros', v_registros
    );
END;
$function$
