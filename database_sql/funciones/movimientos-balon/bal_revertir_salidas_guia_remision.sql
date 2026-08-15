-- Devuelve a almacén los cilindros de una GRE que ya no van (o todos si p_conservar es NULL).
CREATE OR REPLACE FUNCTION bal_revertir_salidas_guia_remision(
    p_id_guia INTEGER,
    p_ids_conservar INTEGER[] DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_mov RECORD;
    v_estado VARCHAR;
    v_id_en_almacen INTEGER;
    v_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'GRE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object('ok', TRUE, 'error', NULL);
    END IF;

    SELECT lo.id INTO v_id_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    FOR v_mov IN
        SELECT m.id, m.id_balon, m.id_almacen_origen, tm.nombre AS tipo_mov
        FROM bal_movimiento m
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        WHERE m.estado = 1
          AND m.id_documento_ref = p_id_guia
          AND m.id_tipo_documento_ref = v_id_tipo_doc
          AND (
              p_ids_conservar IS NULL
              OR NOT (m.id_balon = ANY (p_ids_conservar))
          )
        ORDER BY m.id
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_mov.id_balon AND b.estado = 1;

        v_almacen := v_mov.id_almacen_origen;

        IF v_id_en_almacen IS NOT NULL
           AND COALESCE(v_estado, '') IN (
               'PRESTADO_CLIENTE', 'EN_RECARGA_EXTERNA', 'EN_RUTA_LIMA', 'EN_PODER_CLIENTE'
           )
        THEN
            IF v_almacen IS NULL THEN
                RETURN json_build_object(
                    'ok', FALSE,
                    'error', format(
                        'No se puede devolver el cilindro %s: la guía no tiene almacén de origen',
                        v_mov.id_balon
                    )
                );
            END IF;

            UPDATE bal_balon
            SET
                id_estado_balon = v_id_en_almacen,
                id_cliente_ubicacion = NULL,
                id_almacen = v_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;

        UPDATE bal_movimiento
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_mov.id AND estado = 1;
    END LOOP;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$;
