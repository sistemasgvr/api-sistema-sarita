-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_rechazar_baja_balon
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.596Z
DROP FUNCTION IF EXISTS bal_rechazar_baja_balon(p_id_baja integer, p_id_usuario_autoriza integer, p_motivo_rechazo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_rechazar_baja_balon(p_id_baja integer, p_id_usuario_autoriza integer, p_motivo_rechazo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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

    IF NOT auth_usuario_es_admin_con_permiso(p_id_usuario_autoriza, 'bajas_balon.rechazar')
       AND NOT auth_usuario_es_admin_con_permiso(p_id_usuario_autoriza, 'bajas_balon.aprobar')
    THEN
        RETURN json_build_object(
            'error',
            'Solo un administrador con permiso de rechazar/aprobar bajas de cilindro puede rechazar la solicitud',
            'registro',
            NULL
        );
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
$function$
