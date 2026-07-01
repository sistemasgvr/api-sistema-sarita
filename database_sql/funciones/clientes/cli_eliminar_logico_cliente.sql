CREATE OR REPLACE FUNCTION cli_eliminar_logico_cliente(
    p_id           INT,
    p_id_usuario   INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado INT;
BEGIN
    SET TIME ZONE 'America/Lima';
    SELECT estado INTO v_estado FROM cli_clientes WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', false, 
            'error', 'No existe un cliente con id ' || p_id
        );
    END IF;
    IF v_estado = 0 THEN
        RETURN json_build_object(
            'eliminado', false
        );
    END IF;
    UPDATE cli_clientes
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object(
        'eliminado', true
    );
END;
$$;

select * FROM cli_eliminar_logico_cliente(20, 1);