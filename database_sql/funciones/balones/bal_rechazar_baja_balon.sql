CREATE OR REPLACE FUNCTION bal_rechazar_baja_balon(
    p_id_baja INTEGER,
    p_id_usuario_autoriza INTEGER,
    p_motivo_rechazo VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_motivo_baja INTEGER;
    v_id_estado_actual INTEGER;
    v_observacion VARCHAR;
    v_id_usuario INTEGER;
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

    SELECT bb.id_balon, bb.id_motivo_baja, b.id_estado_balon
    INTO v_id_balon, v_id_motivo_baja, v_id_estado_actual
    FROM bal_baja_balon bb
    INNER JOIN bal_balon b ON b.id = bb.id_balon
    WHERE bb.id = p_id_baja
      AND bb.estado = 1
      AND bb.estado_aprobacion = 'PENDIENTE';

    IF v_id_balon IS NULL THEN
        RETURN json_build_object('error', 'La solicitud de baja no existe o ya fue procesada', 'registro', NULL);
    END IF;

    v_id_usuario := COALESCE(p_id_usuario_auditoria, p_id_usuario_autoriza);
    v_observacion := CASE
        WHEN p_motivo_rechazo IS NOT NULL AND TRIM(p_motivo_rechazo) <> ''
            THEN TRIM(p_motivo_rechazo)
        ELSE NULL
    END;

    UPDATE bal_baja_balon
    SET
        estado_aprobacion = 'RECHAZADA',
        estado = 0,
        id_usuario_autoriza = p_id_usuario_autoriza,
        fecha_autorizacion = NOW(),
        observacion = COALESCE(v_observacion, observacion),
        id_usuario_modificacion = v_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    PERFORM bal_registrar_estado_historial(
        v_id_balon,
        'BAJA_RECHAZADA',
        p_id_baja,
        v_id_motivo_baja,
        v_id_estado_actual,
        v_id_estado_actual,
        COALESCE(v_observacion, 'Solicitud de baja rechazada'),
        v_id_usuario,
        NOW()
    );

    RETURN bal_obtener_baja_balon(p_id_baja);
END;
$function$;
