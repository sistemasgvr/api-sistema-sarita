CREATE OR REPLACE FUNCTION bal_eliminar_recarga_planta(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_compra INTEGER;
    v_det RECORD;
    v_del JSON;
    v_id_estado_en_almacen INTEGER;
    v_id_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT est.nombre, rp.id_comprobante_compra
    INTO v_estado, v_id_compra
    FROM bal_recarga_planta rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
    WHERE rp.id = p_id AND rp.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Orden de recarga no encontrada', 'eliminado', FALSE);
    END IF;

    IF v_estado IN ('RETORNADO', 'CERRADO') THEN
        RETURN json_build_object(
            'error',
            'No se puede eliminar una orden retornada o cerrada',
            'eliminado',
            FALSE
        );
    END IF;

    -- Compra vinculada: no anular/eliminar la orden
    IF v_id_compra IS NOT NULL
       OR EXISTS (
           SELECT 1
           FROM com_comprobante_compra c
           WHERE c.id_recarga_planta = p_id AND c.estado = 1
       )
    THEN
        RETURN json_build_object(
            'error',
            'No se puede eliminar: ya hay una compra registrada con esta orden',
            'eliminado',
            FALSE
        );
    END IF;

    -- Anular movimientos de recarga (por vínculo en detalle o por id_recarga_planta)
    FOR v_det IN
        SELECT DISTINCT mr.id AS id_movimiento_recarga
        FROM bal_movimiento_recarga mr
        WHERE mr.estado = 1
          AND (
              mr.id_recarga_planta = p_id
              OR mr.id IN (
                  SELECT d.id_movimiento_recarga
                  FROM bal_recarga_planta_detalle d
                  WHERE d.id_recarga_planta = p_id
                    AND d.estado = 1
                    AND d.id_movimiento_recarga IS NOT NULL
              )
          )
    LOOP
        v_del := bal_eliminar_movimiento_recarga(v_det.id_movimiento_recarga, p_id_usuario_auditoria);
        IF COALESCE((v_del->>'eliminado')::BOOLEAN, FALSE) IS NOT TRUE
           AND v_del->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_del->>'error', 'eliminado', FALSE);
        END IF;
    END LOOP;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    -- Devolver cilindros a EN_ALMACEN si quedaron en EN_RECARGA_EXTERNA
    -- (p.ej. salida marcada por GRE o movimiento no vinculado).
    IF v_id_estado_en_almacen IS NOT NULL THEN
        FOR v_id_balon IN
            SELECT DISTINCT d.id_balon
            FROM bal_recarga_planta_detalle d
            WHERE d.id_recarga_planta = p_id
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
        LOOP
            UPDATE bal_balon b
            SET
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1
                  FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_RECARGA_EXTERNA'
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM bal_recarga_planta_detalle d2
                  INNER JOIN bal_recarga_planta rp2 ON rp2.id = d2.id_recarga_planta
                  WHERE d2.id_balon = v_id_balon
                    AND d2.estado = 1
                    AND rp2.estado = 1
                    AND rp2.id <> p_id
                    AND rp2.fecha_llegada_almacen IS NULL
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM bal_movimiento_recarga mr
                  WHERE mr.id_balon = v_id_balon
                    AND mr.estado = 1
                    AND mr.fecha_llegada_almacen IS NULL
              );
        END LOOP;
    END IF;

    UPDATE bal_recarga_planta_detalle
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_recarga_planta = p_id AND estado = 1;

    UPDATE bal_recarga_planta
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
