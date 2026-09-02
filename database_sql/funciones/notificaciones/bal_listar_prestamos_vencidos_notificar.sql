-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_prestamos_vencidos_notificar
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.572Z
DROP FUNCTION IF EXISTS bal_listar_prestamos_vencidos_notificar(p_fecha date);

CREATE OR REPLACE FUNCTION bal_listar_prestamos_vencidos_notificar(p_fecha date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_vencimiento, t.id_detalle), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id_detalle', pd.id,
            'id_prestamo', p.id,
            'numero_prestamo', p.numero_prestamo,
            'id_cliente', p.id_cliente,
            'nombre_cliente', COALESCE(c.razon_social, TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno))),
            'id_balon', pd.id_balon,
            'codigo_balon', b.codigo_balon,
            'fecha_vencimiento', COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada),
            'dias_vencido', (v_fecha - COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada))
        ) AS row_data,
        pd.id AS id_detalle,
        COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada) AS fecha_vencimiento
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        LEFT JOIN gen_lista_opciones ed ON ed.id = pd.id_estado
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND COALESCE(ep.nombre, 'ACTIVO') IN ('ACTIVO', 'VENCIDO')
          AND COALESCE(ed.nombre, 'ACTIVO') NOT IN ('DEVUELTO')
          AND COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada) IS NOT NULL
          AND COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada) < v_fecha
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$
