-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_crear_clientes
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.951Z
DROP FUNCTION IF EXISTS cli_crear_clientes(p_codigo_interno character varying, p_razon_social character varying, p_id_tipo_cliente integer, p_id_tipo_persona integer, p_nombres character varying, p_apellido_paterno character varying, p_apellido_materno character varying, p_id_tipo_documento integer, p_numero_documento character varying, p_telefono character varying, p_email character varying, p_es_agente_percepcion boolean, p_es_buen_contribuyente boolean, p_es_agente_retenedor boolean, p_afecto_rus boolean, p_situacion_sunat character varying, p_estado_contribuyente_sunat character varying, p_observacion character varying, p_direccion character varying, p_referencia character varying, p_latitud numeric, p_longitud numeric, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_id_pais integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_crear_clientes(p_codigo_interno character varying DEFAULT NULL::character varying, p_razon_social character varying DEFAULT NULL::character varying, p_id_tipo_cliente integer DEFAULT NULL::integer, p_id_tipo_persona integer DEFAULT NULL::integer, p_nombres character varying DEFAULT NULL::character varying, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_id_tipo_documento integer DEFAULT NULL::integer, p_numero_documento character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_es_agente_percepcion boolean DEFAULT false, p_es_buen_contribuyente boolean DEFAULT false, p_es_agente_retenedor boolean DEFAULT false, p_afecto_rus boolean DEFAULT false, p_situacion_sunat character varying DEFAULT NULL::character varying, p_estado_contribuyente_sunat character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_referencia character varying DEFAULT NULL::character varying, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_id_pais integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_razon_social IS NULL AND p_nombres IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar razon_social o nombres del cliente', 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento
    ) THEN
        RETURN json_build_object('error', 'Ya existe un cliente registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno
    ) THEN
        RETURN json_build_object('error', 'Ya existe un cliente con el código interno ' || p_codigo_interno, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO cli_clientes (
            codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
            nombres, apellido_paterno, apellido_materno,
            id_tipo_documento, numero_documento,
            telefono, email,
            es_agente_percepcion, es_buen_contribuyente, es_agente_retenedor, afecto_rus,
            situacion_sunat, estado_contribuyente_sunat, observacion,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_codigo_interno, p_razon_social, p_id_tipo_cliente, p_id_tipo_persona,
            p_nombres, p_apellido_paterno, p_apellido_materno,
            p_id_tipo_documento, p_numero_documento,
            p_telefono, p_email,
            p_es_agente_percepcion, p_es_buen_contribuyente, p_es_agente_retenedor, p_afecto_rus,
            p_situacion_sunat, p_estado_contribuyente_sunat, p_observacion,
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_cliente;

        IF p_direccion IS NOT NULL THEN
            INSERT INTO cli_direcciones (
                id_cliente, direccion, referencia, latitud, longitud,
                id_departamento, id_provincia, id_distrito, id_pais,
                es_principal, estado,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                v_id_cliente, p_direccion, p_referencia, p_latitud, p_longitud,
                p_id_departamento, p_id_provincia, p_id_distrito, p_id_pais,
                TRUE, 1,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            );
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados (documento o código interno)', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de ubicación o clasificación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el cliente: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN cli_obtener_por_id_cliente(v_id_cliente);
END;
$function$;
