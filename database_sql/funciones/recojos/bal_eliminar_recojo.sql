-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_recojo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.550Z
DROP FUNCTION IF EXISTS bal_eliminar_recojo(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_recojo(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_id_estado_alquilado INTEGER;
    v_det RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre
    INTO v_estado
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Recojo no encontrado');
    END IF;

    IF v_estado NOT IN ('PROGRAMADO', 'EN_RUTA', 'CANCELADO') THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Solo se pueden eliminar recojos PROGRAMADO, EN_RUTA o CANCELADO'
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_alquilado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
    LIMIT 1;

    -- POR_RECOGER → PRESTADO o ALQUILADO según el origen del detalle.
    IF v_id_estado_prestado IS NOT NULL THEN
        FOR v_det IN
            SELECT pd.id_balon
            FROM bal_recojo_detalle rd
            INNER JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
            INNER JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
            INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND pd.fecha_devolucion IS NULL
              AND eb.nombre = 'POR_RECOGER'
        LOOP
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_prestado,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon;
        END LOOP;
    END IF;

    IF v_id_estado_alquilado IS NOT NULL THEN
        FOR v_det IN
            SELECT ad.id_balon
            FROM bal_recojo_detalle rd
            INNER JOIN bal_alquiler_detalle ad ON ad.id = rd.id_alquiler_detalle AND ad.estado = 1
            INNER JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
            INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND ad.fecha_devolucion IS NULL
              AND eb.nombre = 'POR_RECOGER'
        LOOP
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_alquilado,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon;
        END LOOP;
    END IF;

    UPDATE bal_recojo_detalle
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_recojo = p_id AND estado = 1;

    UPDATE bal_recojo
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
