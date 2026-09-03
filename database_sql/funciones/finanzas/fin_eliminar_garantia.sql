-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_eliminar_garantia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_eliminar_garantia(p_id integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_eliminar_garantia(p_id integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE fin_garantia
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error', 'La garantía no existe o ya está inactiva');
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
