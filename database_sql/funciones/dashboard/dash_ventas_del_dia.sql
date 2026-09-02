-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_ventas_del_dia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.662Z
DROP FUNCTION IF EXISTS dash_ventas_del_dia(p_fecha date, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_ventas_del_dia(p_fecha date DEFAULT CURRENT_DATE, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_monto NUMERIC(12,4) := 0;
    v_total_registros BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0), COUNT(*)
    INTO v_total_monto, v_total_registros
    FROM ven_comprobante
    WHERE fecha = p_fecha AND estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            v.id,
            CONCAT(v.serie, '-', v.numero) AS comprobante,
            COALESCE(c.razon_social, CONCAT(c.nombres, ' ', c.apellido_paterno)) AS cliente,
            c.numero_documento AS doc_cliente,
            v.sub_total,
            v.igv,
            v.total_importe,
            cp.nombre AS condicion_pago,
            m.nombre AS moneda,
            v.fecha,
            v.fecha_creacion
        FROM ven_comprobante v
        LEFT JOIN cli_clientes c ON v.id_cliente = c.id
        LEFT JOIN gen_condicion_pago cp ON v.id_condicion_pago = cp.id
        LEFT JOIN gen_lista_opciones m ON v.id_moneda = m.id
        WHERE v.fecha = p_fecha AND v.estado = 1
        ORDER BY v.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'montoTotal', v_total_monto,
        'totalRegistros', v_total_registros,
        'registros', v_registros
    );
END;
$function$
