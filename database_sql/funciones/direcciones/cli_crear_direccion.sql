-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_crear_direccion
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.615Z
DROP FUNCTION IF EXISTS cli_crear_direccion(p_id_cliente integer, p_direccion character varying, p_descripcion character varying, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_referencia character varying, p_latitud numeric, p_longitud numeric, p_es_principal boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_crear_direccion(p_id_cliente integer, p_direccion character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_referencia character varying DEFAULT NULL::character varying, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric, p_es_principal boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_es_principal THEN
        UPDATE cli_direcciones
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_cliente = p_id_cliente AND estado = 1;
    END IF;

    INSERT INTO cli_direcciones (
        id_cliente,
        descripcion,
        direccion,
        id_departamento,
        id_provincia,
        id_distrito,
        referencia,
        latitud,
        longitud,
        es_principal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_descripcion,
        p_direccion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_referencia,
        p_latitud,
        p_longitud,
        COALESCE(p_es_principal, FALSE),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_por_id_direccion(v_id);
END;
$function$
