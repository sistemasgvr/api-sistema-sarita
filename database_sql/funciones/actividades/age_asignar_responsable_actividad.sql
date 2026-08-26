DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION age_asignar_responsable_actividad(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_trabajador_responsable INTEGER DEFAULT NULL
)
RETURNS JSON
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
