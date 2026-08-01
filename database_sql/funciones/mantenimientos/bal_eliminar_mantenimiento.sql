CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
    v_id_comprobante_compra INTEGER;
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_comprobante_venta,
        m.id_comprobante_compra,
        m.id_balon,
        em.nombre,
        b.id_almacen
    INTO
        v_id_comprobante_venta,
        v_id_comprobante_compra,
        v_id_balon,
        v_nombre_estado,
        v_id_almacen
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL OR v_id_comprobante_compra IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_mantenimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene historial de P.H. asociado'
        );
    END IF;

    UPDATE bal_mantenimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si el mantenimiento no estaba finalizado, liberar el cilindro del estado EN_MANTENIMIENTO.
    IF v_id_balon IS NOT NULL AND UPPER(COALESCE(v_nombre_estado, '')) <> 'FINALIZADO' THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_en_almacen,
                id_almacen = COALESCE(id_almacen, v_id_almacen),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1
              AND EXISTS (
                  SELECT 1
                  FROM gen_lista_opciones eb
                  WHERE eb.id = bal_balon.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM bal_mantenimiento m2
                  LEFT JOIN gen_lista_opciones em2 ON em2.id = m2.id_estado
                  WHERE m2.id_balon = v_id_balon
                    AND m2.id <> p_id
                    AND m2.estado = 1
                    AND UPPER(COALESCE(em2.nombre, '')) <> 'FINALIZADO'
              );
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
