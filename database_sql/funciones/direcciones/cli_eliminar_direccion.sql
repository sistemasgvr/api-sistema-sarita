-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_eliminar_direccion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.952Z
DROP FUNCTION IF EXISTS cli_eliminar_direccion(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_eliminar_direccion(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE cli_direcciones
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
