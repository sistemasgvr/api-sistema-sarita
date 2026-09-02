-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_licencia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.698Z
DROP FUNCTION IF EXISTS gen_actualizar_licencia(p_id integer, p_id_chofer integer, p_codigo character varying, p_id_tipo_licencia integer, p_id_categoria_licencia integer, p_fecha_emision date, p_fecha_vencimiento date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_licencia(p_id integer, p_id_chofer integer DEFAULT NULL::integer, p_codigo character varying DEFAULT NULL::character varying, p_id_tipo_licencia integer DEFAULT NULL::integer, p_id_categoria_licencia integer DEFAULT NULL::integer, p_fecha_emision date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_licencia
    SET
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        codigo = COALESCE(p_codigo, codigo),
        id_tipo_licencia = COALESCE(p_id_tipo_licencia, id_tipo_licencia),
        id_categoria_licencia = COALESCE(p_id_categoria_licencia, id_categoria_licencia),
        fecha_emision = COALESCE(p_fecha_emision, fecha_emision),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_licencia(p_id);
END;
$function$
