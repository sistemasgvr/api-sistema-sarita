-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_asignar_responsable_actividad
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(p_id integer, p_id_usuario_auditoria integer, p_id_trabajador_responsable integer);

CREATE OR REPLACE FUNCTION age_asignar_responsable_actividad(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_trabajador_responsable integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE age_actividad
    SET
        id_trabajador_responsable = p_id_trabajador_responsable,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
