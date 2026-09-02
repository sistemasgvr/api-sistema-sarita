-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_editar_contacto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.616Z
DROP FUNCTION IF EXISTS cli_editar_contacto(p_id integer, p_id_cliente integer, p_nombre character varying, p_apellido_paterno character varying, p_apellido_materno character varying, p_direccion character varying, p_email character varying, p_telefono1 character varying, p_telefono2 character varying, p_telefono3 character varying, p_es_principal boolean, p_id_usuario integer);

CREATE OR REPLACE FUNCTION cli_editar_contacto(p_id integer, p_id_cliente integer DEFAULT NULL::integer, p_nombre character varying DEFAULT NULL::character varying, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_telefono1 character varying DEFAULT NULL::character varying, p_telefono2 character varying DEFAULT NULL::character varying, p_telefono3 character varying DEFAULT NULL::character varying, p_es_principal boolean DEFAULT NULL::boolean, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM cli_contacto WHERE id = p_id) THEN
        RETURN json_build_object('error', 'El contacto no existe', 'registro', NULL);
    END IF;

    -- Logica de contacto principal
    IF p_es_principal = TRUE THEN
        UPDATE cli_contacto 
        SET es_principal = FALSE 
        WHERE id_cliente = COALESCE(p_id_cliente, (SELECT id_cliente FROM cli_contacto WHERE id = p_id));
    END IF;

    UPDATE cli_contacto
    SET 
        id_cliente       = COALESCE(p_id_cliente, id_cliente),
        nombre           = COALESCE(p_nombre, nombre),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        direccion        = COALESCE(p_direccion, direccion),
        email            = COALESCE(p_email, email),
        telefono1        = COALESCE(p_telefono1, telefono1),
        telefono2        = COALESCE(p_telefono2, telefono2),
        telefono3        = COALESCE(p_telefono3, telefono3),
        es_principal     = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN cli_obtener_por_id_contacto(p_id);
END;
$function$
