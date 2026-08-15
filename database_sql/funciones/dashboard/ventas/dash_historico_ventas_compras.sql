DROP FUNCTION IF EXISTS dash_historico_ventas_compras(INT);

CREATE OR REPLACE FUNCTION dash_historico_ventas_compras(
    p_anio INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_anio   INT := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH meses AS (
        SELECT generate_series(1, 12) AS mes
    ),
    ventas AS (
        SELECT EXTRACT(MONTH FROM vc.fecha)::INT AS mes, SUM(vc.total_importe) AS total
        FROM ven_comprobante vc
        WHERE vc.estado = 1
          AND vc.id_tipo_comprobante IN (102, 104, 192)
          AND EXTRACT(YEAR FROM vc.fecha) = v_anio
        GROUP BY 1
    ),
    compras AS (
        SELECT EXTRACT(MONTH FROM cc.fecha)::INT AS mes, SUM(cc.total_importe) AS total
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND EXTRACT(YEAR FROM cc.fecha) = v_anio
        GROUP BY 1
    )
    SELECT json_build_object(
        'anio', v_anio,
        'meses', json_agg(
            json_build_object(
                'mes', m.mes,
                'nombreMes', TO_CHAR(TO_DATE(m.mes::text, 'MM'), 'Mon'),
                'ventas', COALESCE(v.total, 0),
                'compras', COALESCE(c.total, 0)
            )
            ORDER BY m.mes
        )
    )
    INTO v_result
    FROM meses m
    LEFT JOIN ventas v ON v.mes = m.mes
    LEFT JOIN compras c ON c.mes = m.mes;

    RETURN v_result;
END;
$$;
