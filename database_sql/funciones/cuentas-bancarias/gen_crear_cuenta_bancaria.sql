DROP FUNCTION IF EXISTS gen_crear_cuenta_bancaria(INTEGER, INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INTEGER);

CREATE OR REPLACE FUNCTION gen_crear_cuenta_bancaria(
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_banco INTEGER DEFAULT NULL,
    p_id_tipo_cuenta INTEGER DEFAULT NULL,
    p_titular VARCHAR DEFAULT NULL,
    p_numero_cuenta VARCHAR DEFAULT NULL,
    p_numero_cuenta_interbancaria VARCHAR DEFAULT NULL,
    p_telefono_billetera VARCHAR DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_es_principal IS TRUE THEN
        UPDATE gen_cuenta_bancaria
        SET es_principal = FALSE
        WHERE (p_id_cliente IS NULL AND id_cliente IS NULL)
           OR (p_id_cliente IS NOT NULL AND id_cliente = p_id_cliente);
    END IF;

    INSERT INTO gen_cuenta_bancaria (
        id_cliente,
        id_banco,
        id_tipo_cuenta,
        titular,
        numero_cuenta,
        numero_cuenta_interbancaria,
        telefono_billetera,
        es_principal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_banco,
        p_id_tipo_cuenta,
        p_titular,
        p_numero_cuenta,
        p_numero_cuenta_interbancaria,
        p_telefono_billetera,
        COALESCE(p_es_principal, FALSE),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_cuenta_bancaria(v_id);
END;
$function$;
