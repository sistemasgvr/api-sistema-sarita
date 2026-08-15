DROP FUNCTION IF EXISTS dash_compras_netas();

CREATE OR REPLACE FUNCTION dash_compras_netas(
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
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
    FROM com_comprobante_compra
    WHERE estado = 1
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta);

    RETURN v_total;
END;
$$;
