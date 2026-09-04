-- Function: gen_actualizar_cuenta_bancaria
-- Fase 3: admite alias y el conjunto de medios de pago asociados.
--
-- El ámbito NO se puede cambiar después de crear la cuenta: pasar una cuenta de
-- cliente a cuenta de empresa (o al revés) dejaría los cobros ya registrados
-- apuntando a una cuenta que significa otra cosa.

DROP FUNCTION IF EXISTS gen_actualizar_cuenta_bancaria(p_id integer, p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS gen_actualizar_cuenta_bancaria(p_id integer, p_id_cliente integer, p_id_banco integer, p_id_tipo_cuenta integer, p_titular character varying, p_numero_cuenta character varying, p_numero_cuenta_interbancaria character varying, p_telefono_billetera character varying, p_es_principal boolean, p_id_usuario_auditoria integer, p_alias character varying, p_medios_pago json);

CREATE OR REPLACE FUNCTION gen_actualizar_cuenta_bancaria(
    p_id integer,
    p_id_cliente integer DEFAULT NULL::integer,
    p_id_banco integer DEFAULT NULL::integer,
    p_id_tipo_cuenta integer DEFAULT NULL::integer,
    p_titular character varying DEFAULT NULL::character varying,
    p_numero_cuenta character varying DEFAULT NULL::character varying,
    p_numero_cuenta_interbancaria character varying DEFAULT NULL::character varying,
    p_telefono_billetera character varying DEFAULT NULL::character varying,
    p_es_principal boolean DEFAULT NULL::boolean,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_alias character varying DEFAULT NULL::character varying,
    p_medios_pago json DEFAULT NULL::json
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_actual RECORD;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente, ambito INTO v_actual
    FROM gen_cuenta_bancaria
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_actual.ambito = 'EMPRESA' AND p_id_cliente IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'No se puede asignar un cliente a una cuenta de la empresa.',
            'registro', NULL
        );
    END IF;

    IF p_es_principal IS TRUE THEN
        UPDATE gen_cuenta_bancaria
        SET es_principal = FALSE
        WHERE id <> p_id
          AND ambito = v_actual.ambito
          AND ((v_actual.ambito = 'EMPRESA') OR (id_cliente = v_actual.id_cliente));
    END IF;

    UPDATE gen_cuenta_bancaria
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_banco = COALESCE(p_id_banco, id_banco),
        id_tipo_cuenta = COALESCE(p_id_tipo_cuenta, id_tipo_cuenta),
        titular = COALESCE(NULLIF(TRIM(p_titular), ''), titular),
        numero_cuenta = COALESCE(p_numero_cuenta, numero_cuenta),
        numero_cuenta_interbancaria = COALESCE(p_numero_cuenta_interbancaria, numero_cuenta_interbancaria),
        telefono_billetera = COALESCE(p_telefono_billetera, telefono_billetera),
        es_principal = COALESCE(p_es_principal, es_principal),
        alias = COALESCE(NULLIF(TRIM(p_alias), ''), alias),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    v_error := gen_sincronizar_medios_cuenta(p_id, p_medios_pago, p_id_usuario_auditoria);
    IF v_error IS NOT NULL THEN
        RAISE EXCEPTION '%', v_error USING ERRCODE = '22023';
    END IF;

    RETURN gen_obtener_cuenta_bancaria(p_id);
END;
$function$;
