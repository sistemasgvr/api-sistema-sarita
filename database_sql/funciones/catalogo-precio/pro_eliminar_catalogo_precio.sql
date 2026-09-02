-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_eliminar_catalogo_precio
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.778Z
DROP FUNCTION IF EXISTS pro_eliminar_catalogo_precio(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_eliminar_catalogo_precio(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE pro_catalogo_precio
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
