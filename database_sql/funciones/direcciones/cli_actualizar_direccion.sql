-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_actualizar_direccion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.951Z
DROP FUNCTION IF EXISTS cli_actualizar_direccion(p_id integer, p_id_cliente integer, p_direccion character varying, p_descripcion character varying, p_id_pais integer, p_id_departamento integer, p_id_provincia integer, p_id_distrito integer, p_referencia character varying, p_latitud numeric, p_longitud numeric, p_es_principal boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_actualizar_direccion(p_id integer, p_id_cliente integer DEFAULT NULL::integer, p_direccion character varying DEFAULT NULL::character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_pais integer DEFAULT NULL::integer, p_id_departamento integer DEFAULT NULL::integer, p_id_provincia integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer, p_referencia character varying DEFAULT NULL::character varying, p_latitud numeric DEFAULT NULL::numeric, p_longitud numeric DEFAULT NULL::numeric, p_es_principal boolean DEFAULT NULL::boolean, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente INTO v_id_cliente
    FROM cli_direcciones
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_es_principal IS TRUE THEN
        UPDATE cli_direcciones
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1 AND id <> p_id;
    END IF;

    UPDATE cli_direcciones
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        direccion = COALESCE(p_direccion, direccion),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_pais = COALESCE(p_id_pais, id_pais),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        referencia = COALESCE(p_referencia, referencia),
        latitud = COALESCE(p_latitud, latitud),
        longitud = COALESCE(p_longitud, longitud),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN cli_obtener_por_id_direccion(p_id);
END;
$function$;
