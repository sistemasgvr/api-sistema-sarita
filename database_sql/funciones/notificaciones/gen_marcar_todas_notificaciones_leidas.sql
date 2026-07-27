CREATE OR REPLACE FUNCTION gen_marcar_todas_notificaciones_leidas(
    p_id_usuario INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_actualizadas INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario IS NULL THEN
        RETURN json_build_object('error', 'El usuario es obligatorio', 'actualizadas', 0);
    END IF;

    UPDATE gen_notificacion
    SET leida = TRUE,
        fecha_lectura = COALESCE(fecha_lectura, NOW()),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_usuario = p_id_usuario
      AND estado = 1
      AND leida = FALSE;

    GET DIAGNOSTICS v_actualizadas = ROW_COUNT;

    RETURN json_build_object('actualizadas', v_actualizadas);
END;
$function$;
