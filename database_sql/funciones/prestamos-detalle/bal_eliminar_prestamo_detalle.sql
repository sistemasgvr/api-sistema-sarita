CREATE OR REPLACE FUNCTION bal_eliminar_prestamo_detalle(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_balon,
        pd.fecha_devolucion,
        p.id_almacen
    INTO
        v_id_balon,
        v_fecha_devolucion,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE bal_prestamo_detalle
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
