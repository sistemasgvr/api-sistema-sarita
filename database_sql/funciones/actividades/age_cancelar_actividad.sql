-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_cancelar_actividad
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_cancelada INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_estado_actual VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_id_estado_cancelada
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(o.nombre)) = 'CANCELADA'
    LIMIT 1;

    IF v_id_estado_cancelada IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No se encontró el estado CANCELADA en EstadoActividad.');
    END IF;

    SELECT a.id_estado_actividad, UPPER(TRIM(ea.nombre))
    INTO v_id_estado_actual, v_nombre_estado_actual
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_nombre_estado_actual = 'CANCELADA' THEN
        RETURN json_build_object('registro', NULL, 'error', 'La actividad ya se encuentra cancelada.');
    END IF;

    UPDATE age_actividad
    SET
        id_estado_actividad = v_id_estado_cancelada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
