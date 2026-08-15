DROP FUNCTION IF EXISTS dash_ventas_netas();

CREATE OR REPLACE FUNCTION dash_ventas_netas(
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_cliente  INT  DEFAULT NULL
)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0)
    INTO v_total
    FROM ven_comprobante
    WHERE estado = 1
      AND id_tipo_comprobante IN (102, 104, 192)
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR id_cliente = p_id_cliente);

    RETURN v_total;
END;
$$;
