-- Total de clientes activos (opcionalmente filtrado por cliente y rango de fecha de registro).

DROP FUNCTION IF EXISTS dash_total_clientes();

CREATE OR REPLACE FUNCTION dash_total_clientes(
    p_id_cliente  INT  DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*)::INTEGER
    INTO v_total
    FROM cli_clientes
    WHERE estado = 1
      AND (p_id_cliente IS NULL OR id = p_id_cliente)
      AND (p_fecha_desde IS NULL OR fecha_creacion::date >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha_creacion::date <= p_fecha_hasta);

    RETURN v_total;
END;
$$;
