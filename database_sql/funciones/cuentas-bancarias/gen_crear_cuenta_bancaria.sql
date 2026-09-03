-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_cuenta_bancaria
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_cuenta_bancaria(p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_cuenta_bancaria(p_id_cliente integer DEFAULT NULL::integer, p_id_banco integer DEFAULT NULL::integer, p_id_tipo_cuenta integer DEFAULT NULL::integer, p_titular character varying DEFAULT NULL::character varying, p_numero_cuenta character varying DEFAULT NULL::character varying, p_numero_cuenta_interbancaria character varying DEFAULT NULL::character varying, p_telefono_billetera character varying DEFAULT NULL::character varying, p_es_principal boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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
