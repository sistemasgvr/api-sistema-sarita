DROP FUNCTION IF EXISTS bal_registrar_estado_historial(
    INTEGER, VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, INTEGER, TIMESTAMP
);

CREATE OR REPLACE FUNCTION bal_registrar_estado_historial(
    p_id_balon INTEGER,
    p_tipo_evento TEXT,
    p_id_baja INTEGER DEFAULT NULL,
    p_id_motivo_baja INTEGER DEFAULT NULL,
    p_id_estado_anterior INTEGER DEFAULT NULL,
    p_id_estado_nuevo INTEGER DEFAULT NULL,
    p_observacion TEXT DEFAULT NULL,
    p_id_usuario INTEGER DEFAULT NULL,
    p_fecha_evento TIMESTAMPTZ DEFAULT NULL
)
RETURNS INTEGER
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
$function$;
