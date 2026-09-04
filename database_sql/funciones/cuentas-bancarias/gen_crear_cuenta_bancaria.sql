-- Function: gen_crear_cuenta_bancaria
-- Fase 3: la tabla deja de ser exclusivamente de clientes. `p_ambito` distingue
-- CLIENTE (la cuenta del cliente, para devoluciones) de EMPRESA (la cuenta
-- propia que recibe el dinero cobrado). Los parámetros nuevos van al final para
-- no romper las llamadas posicionales del modelo NestJS.

DROP FUNCTION IF EXISTS gen_crear_cuenta_bancaria(p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS gen_crear_cuenta_bancaria(p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer, p_ambito character varying, p_alias character varying, p_medios_pago json);

CREATE OR REPLACE FUNCTION gen_crear_cuenta_bancaria(
    p_id_cliente integer DEFAULT NULL::integer,
    p_id_banco integer DEFAULT NULL::integer,
    p_id_tipo_cuenta integer DEFAULT NULL::integer,
    p_titular character varying DEFAULT NULL::character varying,
    p_numero_cuenta character varying DEFAULT NULL::character varying,
    p_numero_cuenta_interbancaria character varying DEFAULT NULL::character varying,
    p_telefono_billetera character varying DEFAULT NULL::character varying,
    p_es_principal boolean DEFAULT false,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_ambito character varying DEFAULT NULL::character varying,
    p_alias character varying DEFAULT NULL::character varying,
    p_medios_pago json DEFAULT NULL::json
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_ambito VARCHAR;
    v_id_empresa INTEGER;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Sin ámbito explícito se deduce del cliente: es como se comportaba antes.
    v_ambito := UPPER(COALESCE(NULLIF(TRIM(p_ambito), ''),
                               CASE WHEN p_id_cliente IS NOT NULL THEN 'CLIENTE' ELSE 'EMPRESA' END));

    IF v_ambito NOT IN ('CLIENTE', 'EMPRESA') THEN
        RETURN json_build_object('error', 'El ámbito debe ser CLIENTE o EMPRESA', 'registro', NULL);
    END IF;

    IF v_ambito = 'CLIENTE' AND p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Una cuenta de ámbito CLIENTE necesita el cliente', 'registro', NULL);
    END IF;

    IF v_ambito = 'EMPRESA' AND p_id_cliente IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'Una cuenta de la empresa no puede estar asociada a un cliente',
            'registro', NULL
        );
    END IF;

    IF NULLIF(TRIM(p_titular), '') IS NULL THEN
        RETURN json_build_object('error', 'El titular es obligatorio', 'registro', NULL);
    END IF;

    IF v_ambito = 'EMPRESA' THEN
        SELECT MIN(id) INTO v_id_empresa FROM gen_empresa WHERE estado = 1;
    END IF;

    -- `es_principal` es único dentro del mismo ámbito/cliente.
    IF p_es_principal IS TRUE THEN
        UPDATE gen_cuenta_bancaria
        SET es_principal = FALSE
        WHERE ambito = v_ambito
          AND ((v_ambito = 'EMPRESA') OR (id_cliente = p_id_cliente));
    END IF;

    INSERT INTO gen_cuenta_bancaria (
        id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta,
        numero_cuenta_interbancaria, telefono_billetera, es_principal,
        ambito, alias, id_empresa,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_id_banco, p_id_tipo_cuenta, TRIM(p_titular), p_numero_cuenta,
        p_numero_cuenta_interbancaria, p_telefono_billetera, COALESCE(p_es_principal, FALSE),
        v_ambito, NULLIF(TRIM(p_alias), ''), v_id_empresa,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_error := gen_sincronizar_medios_cuenta(v_id, p_medios_pago, p_id_usuario_auditoria);
    IF v_error IS NOT NULL THEN
        RAISE EXCEPTION '%', v_error USING ERRCODE = '22023';
    END IF;

    RETURN gen_obtener_cuenta_bancaria(v_id);
END;
$function$;
