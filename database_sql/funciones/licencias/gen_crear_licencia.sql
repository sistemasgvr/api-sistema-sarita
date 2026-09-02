-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_licencia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.709Z
DROP FUNCTION IF EXISTS gen_crear_licencia(p_codigo character varying, p_id_chofer integer, p_fecha_emision date, p_fecha_vencimiento date, p_id_tipo_licencia integer, p_id_categoria_licencia integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_licencia(p_codigo character varying, p_id_chofer integer, p_fecha_emision date, p_fecha_vencimiento date, p_id_tipo_licencia integer DEFAULT NULL::integer, p_id_categoria_licencia integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_licencia (
        id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
        fecha_emision, fecha_vencimiento,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_licencia, p_id_categoria_licencia, p_id_chofer, p_codigo,
        p_fecha_emision, p_fecha_vencimiento,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_licencia(v_id);
END;
$function$
