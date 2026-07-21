CREATE OR REPLACE FUNCTION bal_restaurar_balon(
    p_id_balon INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_actual VARCHAR;
    v_id_estado_actual INTEGER;
    v_id_estado_almacen INTEGER;
    v_id_baja INTEGER;
    v_id_motivo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT b.id_estado_balon, eb.nombre
    INTO v_id_estado_actual, v_estado_actual
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_estado_actual IS NULL OR v_estado_actual NOT IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error',
            'Solo se pueden reactivar cilindros dados de baja o reportados como robo',
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id_balon AND estado = 1 AND estado_aprobacion = 'PENDIENTE'
    ) THEN
        RETURN json_build_object(
            'error',
            'Hay una solicitud de baja pendiente. Resuélvala antes de reactivar.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1;

    IF v_id_estado_almacen IS NULL THEN
        RETURN json_build_object('error', 'No está configurado el estado EN_ALMACEN', 'registro', NULL);
    END IF;

    SELECT bb.id, bb.id_motivo_baja
    INTO v_id_baja, v_id_motivo
    FROM bal_baja_balon bb
    WHERE bb.id_balon = p_id_balon
      AND bb.estado = 1
      AND bb.estado_aprobacion = 'APROBADA'
    ORDER BY bb.fecha_autorizacion DESC NULLS LAST, bb.id DESC
    LIMIT 1;

    IF v_id_baja IS NOT NULL THEN
        UPDATE bal_baja_balon
        SET
            estado_aprobacion = 'REACTIVADA',
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_baja;
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado_almacen,
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_registrar_estado_historial(
        p_id_balon,
        'REACTIVACION',
        v_id_baja,
        v_id_motivo,
        v_id_estado_actual,
        v_id_estado_almacen,
        COALESCE(NULLIF(TRIM(p_observacion), ''), 'Cilindro reactivado / reintegrado al parque'),
        p_id_usuario_auditoria,
        NOW()
    );

    RETURN bal_obtener_balon(p_id_balon);
END;
$function$;
