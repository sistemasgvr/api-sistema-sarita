CREATE OR REPLACE FUNCTION cli_validar_documento_cliente(
    p_numero_documento varchar,
    p_id_excluir       INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM cli_clientes
        WHERE numero_documento = p_numero_documento
          AND (p_id_excluir IS NULL OR id <> p_id_excluir)
    ) INTO v_existe;

    RETURN json_build_object('existe', v_existe);
END;
$$;