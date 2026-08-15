CREATE OR REPLACE FUNCTION bal_eliminar_alquiler_detalle(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_id_alquiler INTEGER;
    v_id_cliente INTEGER;
    v_fecha_devolucion DATE;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_balon,
        ad.fecha_devolucion,
        ad.id_alquiler,
        al.id_almacen,
        al.id_cliente
    INTO
        v_id_balon,
        v_fecha_devolucion,
        v_id_alquiler,
        v_id_almacen,
        v_id_cliente
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE bal_alquiler_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si el cilindro seguía pendiente de devolución, liberarlo a almacén.
    IF v_id_balon IS NOT NULL AND v_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            SELECT lo.id INTO v_id_tipo_movimiento
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_documento_ref
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_movimiento IS NOT NULL THEN
                v_mov := bal_crear_movimiento(
                    v_id_balon,
                    v_id_tipo_movimiento,
                    v_id_alquiler,
                    v_id_tipo_documento_ref,
                    v_id_cliente,
                    NULL::INTEGER,
                    v_id_almacen,
                    NOW()::TIMESTAMP,
                    'Entrada por quitar cilindro del alquiler'::VARCHAR,
                    p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_mov->>'error';
                END IF;
            END IF;

            UPDATE bal_balon
            SET
                id_cliente_ubicacion = NULL,
                id_almacen = COALESCE(v_id_almacen, id_almacen),
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
