CREATE OR REPLACE FUNCTION bal_rechazar_baja_balon(
    p_id_baja INTEGER,
    p_id_usuario_autoriza INTEGER,
    p_motivo_rechazo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_autoriza IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el administrador que rechaza', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM auth_usuarios_roles ur
        INNER JOIN auth_roles r ON ur.id_rol = r.id
        WHERE ur.id_usuario = p_id_usuario_autoriza
          AND ur.estado = TRUE
          AND r.estado = TRUE
          AND r.nombre = 'Administrador'
    ) THEN
        RETURN json_build_object('error', 'Solo un administrador puede rechazar la solicitud', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM bal_baja_balon
        WHERE id = p_id_baja
          AND estado = 1
          AND estado_aprobacion = 'PENDIENTE'
    ) THEN
        RETURN json_build_object('error', 'La solicitud de baja no existe o ya fue procesada', 'registro', NULL);
    END IF;

    UPDATE bal_baja_balon
    SET
        estado_aprobacion = 'RECHAZADA',
        estado = 0,
        id_usuario_autoriza = p_id_usuario_autoriza,
        fecha_autorizacion = NOW(),
        observacion = CASE
            WHEN p_motivo_rechazo IS NOT NULL AND TRIM(p_motivo_rechazo) <> ''
                THEN TRIM(p_motivo_rechazo)
            ELSE observacion
        END,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, p_id_usuario_autoriza),
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    RETURN bal_obtener_baja_balon(p_id_baja);
END;
$function$;
