-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_crear_contacto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.614Z
DROP FUNCTION IF EXISTS cli_crear_contacto(p_id_cliente integer, p_nombre character varying, p_apellido_paterno character varying, p_apellido_materno character varying, p_direccion character varying, p_email character varying, p_telefono1 character varying, p_telefono2 character varying, p_telefono3 character varying, p_es_principal boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_crear_contacto(p_id_cliente integer, p_nombre character varying DEFAULT NULL::character varying, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_telefono1 character varying DEFAULT NULL::character varying, p_telefono2 character varying DEFAULT NULL::character varying, p_telefono3 character varying DEFAULT NULL::character varying, p_es_principal boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El id_cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del contacto es obligatorio', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE cli_contacto 
        SET es_principal = FALSE 
        WHERE id_cliente = p_id_cliente;
    END IF;

    INSERT INTO cli_contacto (
        id_cliente, nombre, apellido_paterno, apellido_materno, 
        direccion, email, telefono1, telefono2, telefono3, 
        es_principal, estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_nombre, p_apellido_paterno, p_apellido_materno, 
        p_direccion, p_email, p_telefono1, p_telefono2, p_telefono3, 
        p_es_principal, 1, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_por_id_contacto(v_id);
END;
$function$
