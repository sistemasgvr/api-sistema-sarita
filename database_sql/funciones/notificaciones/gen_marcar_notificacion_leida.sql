-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_marcar_notificacion_leida
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.739Z
DROP FUNCTION IF EXISTS gen_marcar_notificacion_leida(p_id integer, p_id_usuario integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_marcar_notificacion_leida(p_id integer, p_id_usuario integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_notificacion
    SET leida = TRUE,
        fecha_lectura = COALESCE(fecha_lectura, NOW()),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND id_usuario = p_id_usuario
      AND estado = 1
      AND leida = FALSE;

    IF NOT FOUND THEN
        -- Ya leída o inexistente: devolver registro actual si pertenece al usuario
        RETURN gen_obtener_notificacion(p_id, p_id_usuario);
    END IF;

    RETURN gen_obtener_notificacion(p_id, p_id_usuario);
END;
$function$
