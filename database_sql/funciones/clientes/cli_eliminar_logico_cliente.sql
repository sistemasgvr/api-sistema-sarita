DROP FUNCTION IF EXISTS cli_eliminar_logico_cliente(INT, INT);
CREATE OR REPLACE FUNCTION cli_eliminar_logico_cliente(
    p_id           INT,
    p_id_usuario_auditoria   INT DEFAULT NULL
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
            'id', p_id
        );
    END IF;

    IF v_estado = 0 THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id
        );
    END IF;

    UPDATE cli_clientes
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE cli_direcciones
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_chofer
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_vehiculo
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_cuenta_bancaria
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE cli_contacto
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    RETURN json_build_object(
        'eliminado', true,
        'id', p_id
    );
END;
$$;
