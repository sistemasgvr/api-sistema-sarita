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
BEGIN
    SET TIME ZONE 'America/Lima'; 

    UPDATE age_actividad
    SET
        titulo = COALESCE(p_titulo, titulo), 
        descripcion = COALESCE(p_descripcion, descripcion), 
        fecha_programada = COALESCE(p_fecha_programada, fecha_programada), 
        hora_inicio_estimada = COALESCE(p_hora_inicio_estimada, hora_inicio_estimada), 
        hora_fin_estimada = COALESCE(p_hora_fin_estimada, hora_fin_estimada), 
        fecha_hora_cierre = COALESCE(p_fecha_hora_cierre, fecha_hora_cierre), 
        id_tipo_actividad = COALESCE(p_id_tipo_actividad, id_tipo_actividad), 
        id_prioridad = COALESCE(p_id_prioridad, id_prioridad), 
        id_cliente = COALESCE(p_id_cliente, id_cliente), 
        id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable), 
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