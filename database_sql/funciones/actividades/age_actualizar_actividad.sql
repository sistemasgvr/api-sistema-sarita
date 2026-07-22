-- DROP FUNCTION IF EXISTS age_actualizar_actividad;

-- CREATE OR REPLACE FUNCTION age_actualizar_actividad(
--     p_id INTEGER,
--     p_titulo VARCHAR DEFAULT NULL,
--     p_descripcion TEXT DEFAULT NULL,
--     p_fecha_programada DATE DEFAULT NULL,
--     p_hora_inicio_estimada TIME DEFAULT NULL,
--     p_hora_fin_estimada TIME DEFAULT NULL,
--     p_fecha_hora_cierre TIMESTAMP DEFAULT NULL,
--     p_id_tipo_actividad INTEGER DEFAULT NULL,
--     p_id_prioridad INTEGER DEFAULT NULL, 
--     p_id_cliente INTEGER DEFAULT NULL,
--     p_id_usuario_responsable INTEGER DEFAULT NULL,
--     p_id_estado_actividad INTEGER DEFAULT NULL,
--     p_observaciones VARCHAR DEFAULT NULL,
--     p_id_usuario_auditoria INTEGER DEFAULT NULL
-- )
-- RETURNS JSON
-- LANGUAGE plpgsql
-- AS $function$
-- BEGIN
--     SET TIME ZONE 'America/Lima'; 

--     UPDATE age_actividad
--     SET
--         titulo = COALESCE(p_titulo, titulo), 
--         descripcion = COALESCE(p_descripcion, descripcion), 
--         fecha_programada = COALESCE(p_fecha_programada, fecha_programada), 
--         hora_inicio_estimada = COALESCE(p_hora_inicio_estimada, hora_inicio_estimada), 
--         hora_fin_estimada = COALESCE(p_hora_fin_estimada, hora_fin_estimada), 
--         fecha_hora_cierre = COALESCE(p_fecha_hora_cierre, fecha_hora_cierre), 
--         id_tipo_actividad = COALESCE(p_id_tipo_actividad, id_tipo_actividad), 
--         id_prioridad = COALESCE(p_id_prioridad, id_prioridad), 
--         id_cliente = COALESCE(p_id_cliente, id_cliente), 
--         id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable), 
--         id_estado_actividad = COALESCE(p_id_estado_actividad, id_estado_actividad), 
--         observaciones = COALESCE(p_observaciones, observaciones), 
--         id_usuario_modificacion = p_id_usuario_auditoria, 
--         fecha_modificacion = NOW() 
--     WHERE id = p_id AND estado = 1; 

--     IF NOT FOUND THEN 
--         RETURN json_build_object('registro', NULL); 
--     END IF; 

--     RETURN age_obtener_actividad(p_id); 
-- END;
-- $function$;

DROP FUNCTION IF EXISTS age_actualizar_actividad;

CREATE OR REPLACE FUNCTION age_actualizar_actividad(
    p_id INTEGER,
    p_titulo VARCHAR DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_inicio_estimada TIME DEFAULT NULL,
    p_hora_fin_estimada TIME DEFAULT NULL,
    p_fecha_hora_cierre TIMESTAMP DEFAULT NULL,
    p_id_tipo_actividad INTEGER DEFAULT NULL,
    p_id_prioridad INTEGER DEFAULT NULL, 
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_id_estado_actividad INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_h_inicio TIME;
    v_h_fin TIME;
    v_responsable INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima'; 

    SELECT fecha_programada, hora_inicio_estimada, hora_fin_estimada, id_usuario_responsable
    INTO v_fecha, v_h_inicio, v_h_fin, v_responsable
    FROM age_actividad WHERE id = p_id AND estado = 1;

    v_fecha := COALESCE(p_fecha_programada, v_fecha);
    v_h_inicio := COALESCE(p_hora_inicio_estimada, v_h_inicio);
    v_h_fin := COALESCE(p_hora_fin_estimada, v_h_fin);
    v_responsable := COALESCE(p_id_usuario_responsable, v_responsable);

    IF v_h_inicio IS NOT NULL AND v_h_fin IS NOT NULL THEN
        IF v_h_inicio >= v_h_fin THEN
            RAISE EXCEPTION 'La hora de inicio estimada debe ser menor a la hora de fin estimada.';
        END IF;
    END IF;

    IF v_responsable IS NOT NULL AND v_h_inicio IS NOT NULL AND v_h_fin IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 
            FROM age_actividad
            WHERE id_usuario_responsable = v_responsable
              AND fecha_programada = v_fecha
              AND estado = 1
              AND id <> p_id 
              AND (
                  (v_h_inicio >= hora_inicio_estimada AND v_h_inicio < hora_fin_estimada)
                  OR (v_h_fin > hora_inicio_estimada AND v_h_fin <= hora_fin_estimada)
                  OR (v_h_inicio <= hora_inicio_estimada AND v_h_fin >= hora_fin_estimada)
              )
        ) THEN
            RAISE EXCEPTION 'El usuario responsable ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.';
        END IF;
    END IF;

    UPDATE age_actividad
    SET
        titulo = COALESCE(p_titulo, titulo), 
        descripcion = COALESCE(p_descripcion, descripcion), 
        fecha_programada = v_fecha, 
        hora_inicio_estimada = v_h_inicio, 
        hora_fin_estimada = v_h_fin, 
        fecha_hora_cierre = COALESCE(p_fecha_hora_cierre, fecha_hora_cierre), 
        id_tipo_actividad = COALESCE(p_id_tipo_actividad, id_tipo_actividad), 
        id_prioridad = COALESCE(p_id_prioridad, id_prioridad), 
        id_cliente = COALESCE(p_id_cliente, id_cliente), 
        id_usuario_responsable = v_responsable, 
        id_estado_actividad = COALESCE(p_id_estado_actividad, id_estado_actividad), 
        observaciones = COALESCE(p_observaciones, observaciones), 
        id_usuario_modificacion = p_id_usuario_auditoria, 
        fecha_modificacion = NOW() 
    WHERE id = p_id AND estado = 1; 

    IF NOT FOUND THEN 
        RETURN json_build_object('registro', NULL); 
    END IF; 

    RETURN age_obtener_actividad(p_id); 
END;
$function$;