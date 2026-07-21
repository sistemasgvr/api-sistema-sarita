CREATE OR REPLACE FUNCTION bal_registrar_ph_historial(
    p_id_balon INTEGER,
    p_fecha_prueba DATE,
    p_vigencia_anios INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT FALSE,
    p_numero_certificado VARCHAR DEFAULT NULL,
    p_id_mantenimiento INTEGER DEFAULT NULL,
    p_id_movimiento_recarga INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_vigencia INTEGER;
    v_fecha_prueba DATE;
    v_fecha_proxima DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_fecha_prueba IS NULL THEN
        RETURN json_build_object('error', 'La fecha de prueba hidrostática es obligatoria', 'registro', NULL);
    END IF;

    -- Formato de negocio: solo mes/año (día 1)
    v_fecha_prueba := make_date(
        EXTRACT(YEAR FROM p_fecha_prueba)::INT,
        EXTRACT(MONTH FROM p_fecha_prueba)::INT,
        1
    );

    SELECT COALESCE(
        p_vigencia_anios,
        b.vigencia_prueba_hidrostatica_anios,
        tb.vigencia_ph_anios,
        5
    )
    INTO v_vigencia
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    WHERE b.id = p_id_balon;

    v_fecha_proxima := (v_fecha_prueba + make_interval(years => v_vigencia))::DATE;

    UPDATE bal_balon_ph_historial
    SET es_vigente = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_balon = p_id_balon AND es_vigente = TRUE AND estado = 1;

    INSERT INTO bal_balon_ph_historial (
        id_balon, fecha_prueba, vigencia_anios, fecha_proxima,
        id_organo_inspector, organo_inspector_no_aplica, numero_certificado,
        id_mantenimiento, id_movimiento_recarga, es_vigente, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, v_fecha_prueba, v_vigencia, v_fecha_proxima,
        p_id_organo_inspector, COALESCE(p_organo_inspector_no_aplica, FALSE), p_numero_certificado,
        p_id_mantenimiento, p_id_movimiento_recarga, TRUE, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    UPDATE bal_balon
    SET
        fecha_ultima_prueba_hidrostatica = v_fecha_prueba,
        vigencia_prueba_hidrostatica_anios = v_vigencia,
        fecha_proxima_prueba_hidrostatica = v_fecha_proxima,
        id_organo_inspector = COALESCE(p_id_organo_inspector, id_organo_inspector),
        organo_inspector_no_aplica = COALESCE(p_organo_inspector_no_aplica, organo_inspector_no_aplica),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN bal_obtener_ph_historial(v_id);
END;
$function$;
