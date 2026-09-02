-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_contar_notificaciones_no_leidas
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.701Z
DROP FUNCTION IF EXISTS gen_contar_notificaciones_no_leidas(p_id_usuario integer);

CREATE OR REPLACE FUNCTION gen_contar_notificaciones_no_leidas(p_id_usuario integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario IS NULL THEN
        RETURN json_build_object('total', 0);
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_total
    FROM gen_notificacion
    WHERE id_usuario = p_id_usuario
      AND estado = 1
      AND leida = FALSE;

    RETURN json_build_object('total', COALESCE(v_total, 0));
END;
$function$
