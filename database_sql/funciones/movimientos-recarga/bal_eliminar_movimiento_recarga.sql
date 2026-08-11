CREATE OR REPLACE FUNCTION bal_eliminar_movimiento_recarga(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada DATE;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_doc_recarga INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_movimiento_recarga = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la recarga porque tiene historial de P.H. asociado'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_movimiento_recarga
        WHERE id = p_id AND estado = 1 AND id_comprobante IS NOT NULL
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la recarga porque tiene un comprobante asociado'
        );
    END IF;

    SELECT id_balon, fecha_llegada_almacen
    INTO v_id_balon, v_fecha_llegada
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    -- Soft-delete movimientos del libro vinculados a esta recarga.
    UPDATE bal_movimiento
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE estado = 1
      AND id_documento_ref = p_id
      AND (
          v_id_tipo_doc_recarga IS NULL
          OR id_tipo_documento_ref = v_id_tipo_doc_recarga
          OR id_tipo_movimiento IN (
              SELECT lo.id
              FROM gen_lista_opciones lo
              INNER JOIN gen_lista l ON lo.id_lista = l.id
              WHERE l.nombre = 'TipoMovBalon'
                AND lo.nombre IN ('SALIDA_PLANTA_EXTERNA', 'ENTRADA_PLANTA_EXTERNA')
                AND lo.estado = 1
          )
      );

    UPDATE bal_movimiento_recarga
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_id_balon IS NOT NULL AND v_fecha_llegada IS NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1
              AND EXISTS (
                  SELECT 1
                  FROM gen_lista_opciones eb
                  WHERE eb.id = bal_balon.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_RECARGA_EXTERNA'
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM bal_movimiento_recarga mr
                  WHERE mr.id_balon = v_id_balon
                    AND mr.id <> p_id
                    AND mr.estado = 1
                    AND mr.fecha_llegada_almacen IS NULL
              );
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
