-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_actualizar_movimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.767Z
DROP FUNCTION IF EXISTS pro_actualizar_movimiento(p_id integer, p_fecha date, p_glosa character varying, p_id_documento_ref integer, p_id_tipo_documento_ref integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_actualizar_movimiento(p_id integer, p_fecha date DEFAULT NULL::date, p_glosa character varying DEFAULT NULL::character varying, p_id_documento_ref integer DEFAULT NULL::integer, p_id_tipo_documento_ref integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_movimientos
    SET
        fecha = COALESCE(p_fecha, fecha),
        glosa = COALESCE(p_glosa, glosa),
        id_documento_ref = COALESCE(p_id_documento_ref, id_documento_ref),
        id_tipo_documento_ref = COALESCE(p_id_tipo_documento_ref, id_tipo_documento_ref),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_movimiento(p_id);
END;
$function$
