CREATE OR REPLACE FUNCTION cli_obtener_por_id_cliente(
    p_id INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_cliente RECORD;
BEGIN
    SELECT * INTO v_cliente FROM cli_clientes WHERE id = p_id;
    RETURN json_build_object(
        'registro', CASE WHEN v_cliente.id IS NOT NULL THEN row_to_json(v_cliente) ELSE NULL END,
        'error', NULL
    );
END;
$$;