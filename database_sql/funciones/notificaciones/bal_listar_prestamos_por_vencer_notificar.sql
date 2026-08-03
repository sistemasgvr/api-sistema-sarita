-- Detalles de préstamo que vencen entre p_dias_min y p_dias_max días (inclusive).
CREATE OR REPLACE FUNCTION bal_listar_prestamos_por_vencer_notificar(
    p_dias_min INTEGER DEFAULT 3,
    p_dias_max INTEGER DEFAULT 7,
    p_fecha DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_min INTEGER;
    v_max INTEGER;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_min := GREATEST(COALESCE(p_dias_min, 3), 0);
    v_max := GREATEST(COALESCE(p_dias_max, 7), v_min);

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
            'dias_para_vencer', (COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada) - v_fecha)
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
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'
          AND COALESCE(ed.nombre, 'ACTIVO') NOT IN ('DEVUELTO', 'VENCIDO')
          AND COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada) IS NOT NULL
          AND COALESCE(pd.fecha_vencimiento, p.fecha_retorno_pactada)
              BETWEEN (v_fecha + v_min) AND (v_fecha + v_max)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
