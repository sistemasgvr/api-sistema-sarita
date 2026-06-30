CREATE OR REPLACE FUNCTION cli_obtener_por_id_cliente(
    p_id INT
)
RETURNS SETOF cli_clientes
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id) THEN
        RAISE EXCEPTION 'No existe un cliente con id %', p_id;
    END IF;

    RETURN QUERY
    SELECT * FROM cli_clientes WHERE id = p_id;
END;
$$;