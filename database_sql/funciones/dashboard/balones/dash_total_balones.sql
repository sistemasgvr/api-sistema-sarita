-- Total de balones activos (opcionalmente por ubicación en un cliente).

DROP FUNCTION IF EXISTS dash_total_balones();

CREATE OR REPLACE FUNCTION dash_total_balones(
    p_id_cliente INT DEFAULT NULL
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
  FROM bal_balon
  WHERE estado = 1
    AND (p_id_cliente IS NULL OR id_cliente_ubicacion = p_id_cliente);

  RETURN v_total;
END;
$$;
