-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_cuenta_bancaria
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.696Z
DROP FUNCTION IF EXISTS gen_actualizar_cuenta_bancaria(p_id integer, p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_cuenta_bancaria(p_id integer, p_id_cliente integer DEFAULT NULL::integer, p_id_banco integer DEFAULT NULL::integer, p_id_tipo_cuenta integer DEFAULT NULL::integer, p_titular character varying DEFAULT NULL::character varying, p_numero_cuenta character varying DEFAULT NULL::character varying, p_numero_cuenta_interbancaria character varying DEFAULT NULL::character varying, p_telefono_billetera character varying DEFAULT NULL::character varying, p_es_principal boolean DEFAULT NULL::boolean, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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
$function$
