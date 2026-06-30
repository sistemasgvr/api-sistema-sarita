CREATE OR REPLACE FUNCTION cli_restaurar_cliente(
    p_id          INT,
    p_id_usuario   INT DEFAULT NULL
)
RETURNS TABLE (id INT, mensaje varchar)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id) THEN
        RAISE EXCEPTION 'No existe un cliente con id %', p_id;
    END IF;

    IF EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'El cliente con id % ya se encuentra activo', p_id;
    END IF;

    UPDATE cli_clientes
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE cli_clientes.id = p_id;

    RETURN QUERY SELECT p_id, 'Cliente reactivado correctamente'::varchar;
END;
$$;
