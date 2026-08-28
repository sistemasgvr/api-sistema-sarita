CREATE OR REPLACE FUNCTION bal_generar_recojo_recarga_planta(
    p_id_recarga_planta INTEGER,
    p_fecha_programada DATE DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_proveedor INTEGER;
    v_rp_estado VARCHAR;
    v_fecha DATE;
    v_detalles JSONB := '[]'::JSONB;
    v_item JSONB;
    v_id_balon INTEGER;
    v_id INTEGER;
    v_existente INTEGER;
    v_rec RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT rp.id_proveedor, est.nombre
    INTO v_proveedor, v_rp_estado
    FROM bal_recarga_planta rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
    WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

    IF v_proveedor IS NULL THEN
        RETURN json_build_object('error', 'Orden de recarga en planta no encontrada', 'registro', NULL);
    END IF;

    IF v_rp_estado NOT IN ('ENVIADO', 'CERRADO') THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta aún no ha sido enviada',
            'registro', NULL
        );
    END IF;

    SELECT r.id INTO v_existente
    FROM bal_recojo r
    WHERE r.id_recarga_planta = p_id_recarga_planta
      AND r.estado = 1
    LIMIT 1;

    IF v_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'Ya existe un recojo para esta orden de recarga en planta',
            'registro', bal_obtener_recojo(v_existente)
        );
    END IF;

    v_fecha := COALESCE(p_fecha_programada, CURRENT_DATE + 5);

    FOR v_rec IN
        SELECT d.id_balon
        FROM bal_recarga_planta_detalle d
        WHERE d.id_recarga_planta = p_id_recarga_planta
          AND d.estado = 1
    LOOP
        v_id_balon := v_rec.id_balon;
        IF NOT EXISTS (
            SELECT 1
            FROM bal_balon b
            JOIN gen_lista_opciones e ON e.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1 AND e.nombre = 'EN_RECARGA_EXTERNA'
        ) THEN
            RETURN json_build_object(
                'error', 'El balón ' || v_id_balon || ' no está en estado EN_RECARGA_EXTERNA',
                'registro', NULL
            );
        END IF;

        v_item := jsonb_build_object('id_balon', v_id_balon, 'observacion', NULL);
        v_detalles := v_detalles || jsonb_build_array(v_item);
    END LOOP;

    IF jsonb_array_length(v_detalles) = 0 THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta no tiene cilindros para recojo',
            'registro', NULL
        );
    END IF;

    RETURN bal_crear_recojo(
        v_proveedor,
        NULL,
        NULL,
        p_id_recarga_planta,
        v_fecha,
        NULL::TIME,
        p_id_usuario_responsable,
        NULLIF(TRIM(p_observacion), ''),
        v_detalles::JSON,
        p_id_usuario_auditoria
    );
END;
$function$;
