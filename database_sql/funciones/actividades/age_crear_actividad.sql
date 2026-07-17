DROP FUNCTION IF EXISTS age_crear_actividad;

CREATE OR REPLACE FUNCTION age_crear_actividad(
    p_titulo VARCHAR,
    p_descripcion TEXT,
    p_fecha_programada DATE,
    p_hora_inicio_estimada TIME,
    p_hora_fin_estimada TIME,
    p_id_tipo_actividad INTEGER,
    p_id_prioridad INTEGER, 
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
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO age_actividad (
        titulo,
        descripcion,
        fecha_programada,
        hora_inicio_estimada,
        hora_fin_estimada,
        id_tipo_actividad,
        id_prioridad, 
        id_cliente,
        id_usuario_responsable,
        id_estado_actividad,
        observaciones,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_titulo,
        p_descripcion,
        p_fecha_programada,
        p_hora_inicio_estimada,
        p_hora_fin_estimada,
        p_id_tipo_actividad,
        p_id_prioridad, 
        p_id_cliente,
        p_id_usuario_responsable,
        p_id_estado_actividad,
        p_observaciones,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN age_obtener_actividad(v_id);
END;
$function$;