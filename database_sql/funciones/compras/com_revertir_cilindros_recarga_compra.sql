CREATE OR REPLACE FUNCTION com_revertir_cilindros_recarga_compra(
    p_id_recarga_planta INTEGER,
    p_id_comprobante INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
    v_estado VARCHAR;
    v_id_recarga_ext INTEGER;
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_entrada INTEGER;
BEGIN
    SELECT lo.id INTO v_id_recarga_ext
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovBalon'
      AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
      AND lo.estado = 1
    ORDER BY CASE lo.nombre WHEN 'ENTRADA_LLENADO' THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon
        FROM bal_recarga_planta_detalle d
        WHERE d.id_recarga_planta = p_id_recarga_planta
          AND d.estado = 1
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_det.id_balon AND b.estado = 1;

        IF COALESCE(v_estado, '') NOT IN ('EN_ALMACEN', 'EN_RECARGA_EXTERNA') THEN
            RAISE EXCEPTION
                'No se puede anular la compra: el cilindro % ya no está en almacén ni en recarga externa (estado %).',
                v_det.id_balon,
                COALESCE(v_estado, 'sin estado');
        END IF;

        IF COALESCE(v_estado, '') = 'EN_ALMACEN' AND v_id_recarga_ext IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_recarga_ext,
                id_almacen = NULL,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon AND estado = 1;
        END IF;

        UPDATE bal_movimiento m
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE m.estado = 1
          AND m.id_balon = v_det.id_balon
          AND (
              (v_id_tipo_doc_compra IS NOT NULL AND m.id_documento_ref = p_id_comprobante AND m.id_tipo_documento_ref = v_id_tipo_doc_compra)
              OR (v_id_tipo_doc_recarga IS NOT NULL AND m.id_documento_ref = p_id_recarga_planta AND m.id_tipo_documento_ref = v_id_tipo_doc_recarga)
          )
          AND (
              v_id_tipo_entrada IS NULL
              OR m.id_tipo_movimiento IN (
                  SELECT lo.id
                  FROM gen_lista_opciones lo
                  INNER JOIN gen_lista l ON l.id = lo.id_lista
                  WHERE l.nombre = 'TipoMovBalon'
                    AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
              )
          );
    END LOOP;
END;
$function$;
