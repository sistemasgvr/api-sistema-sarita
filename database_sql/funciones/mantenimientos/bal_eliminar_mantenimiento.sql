-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.546Z
DROP FUNCTION IF EXISTS bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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

    -- Si no estaba finalizado, restaurar custodia previa (alquiler / préstamo / almacén).
    IF v_id_balon IS NOT NULL AND UPPER(COALESCE(v_nombre_estado, '')) <> 'FINALIZADO' THEN
        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = v_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT al.id_cliente
                    FROM bal_alquiler_detalle ad
                    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler
                    WHERE ad.id_balon = v_id_balon
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                    ORDER BY ad.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSIF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT p2.id_cliente
                    FROM bal_prestamo_detalle pd
                    INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo
                    WHERE pd.id_balon = v_id_balon
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                    ORDER BY pd.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSE
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
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
