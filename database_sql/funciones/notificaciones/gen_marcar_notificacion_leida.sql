CREATE OR REPLACE FUNCTION gen_marcar_notificacion_leida(
    p_id INTEGER,
    p_id_usuario INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
$function$;
