-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_estado_historial
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.598Z
DROP FUNCTION IF EXISTS bal_registrar_estado_historial(p_id_balon integer, p_tipo_evento text, p_id_baja integer, p_id_motivo_baja integer, p_id_estado_anterior integer, p_id_estado_nuevo integer, p_observacion text, p_id_usuario integer, p_fecha_evento timestamp with time zone);

CREATE OR REPLACE FUNCTION bal_registrar_estado_historial(p_id_balon integer, p_tipo_evento text, p_id_baja integer DEFAULT NULL::integer, p_id_motivo_baja integer DEFAULT NULL::integer, p_id_estado_anterior integer DEFAULT NULL::integer, p_id_estado_nuevo integer DEFAULT NULL::integer, p_observacion text DEFAULT NULL::text, p_id_usuario integer DEFAULT NULL::integer, p_fecha_evento timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_balon IS NULL THEN
        RETURN NULL;
    END IF;

    IF p_tipo_evento IS NULL OR p_tipo_evento NOT IN (
        'SOLICITUD_BAJA', 'BAJA_APROBADA', 'BAJA_RECHAZADA', 'REACTIVACION'
    ) THEN
        RETURN NULL;
    END IF;

    INSERT INTO bal_balon_estado_historial (
        id_balon, tipo_evento, id_baja, id_motivo_baja,
        id_estado_anterior, id_estado_nuevo, observacion,
        id_usuario, fecha_evento,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_tipo_evento, p_id_baja, p_id_motivo_baja,
        p_id_estado_anterior, p_id_estado_nuevo, NULLIF(TRIM(p_observacion), ''),
        p_id_usuario, COALESCE(p_fecha_evento, NOW()),
        p_id_usuario, p_id_usuario
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$function$
