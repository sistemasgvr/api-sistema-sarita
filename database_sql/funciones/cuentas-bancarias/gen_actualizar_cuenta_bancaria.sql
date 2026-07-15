    DROP FUNCTION IF EXISTS gen_actualizar_cuenta_bancaria(INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_cuenta_bancaria(
    p_id INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_banco INTEGER DEFAULT NULL,
    p_id_tipo_cuenta INTEGER DEFAULT NULL,
    p_titular VARCHAR DEFAULT NULL,
    p_numero_cuenta VARCHAR DEFAULT NULL,
    p_numero_cuenta_interbancaria VARCHAR DEFAULT NULL,
    p_telefono_billetera VARCHAR DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_current_id_cliente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente INTO v_current_id_cliente
    FROM gen_cuenta_bancaria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_es_principal IS TRUE THEN
        UPDATE gen_cuenta_bancaria
        SET es_principal = FALSE
        WHERE id <> p_id
          AND ((v_current_id_cliente IS NULL AND id_cliente IS NULL)
               OR (v_current_id_cliente IS NOT NULL AND id_cliente = v_current_id_cliente));
    END IF;

    UPDATE gen_cuenta_bancaria
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_banco = COALESCE(p_id_banco, id_banco),
        id_tipo_cuenta = COALESCE(p_id_tipo_cuenta, id_tipo_cuenta),
        titular = COALESCE(p_titular, titular),
        numero_cuenta = COALESCE(p_numero_cuenta, numero_cuenta),
        numero_cuenta_interbancaria = COALESCE(p_numero_cuenta_interbancaria, numero_cuenta_interbancaria),
        telefono_billetera = COALESCE(p_telefono_billetera, telefono_billetera),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN gen_obtener_cuenta_bancaria(p_id);
END;
$function$;
