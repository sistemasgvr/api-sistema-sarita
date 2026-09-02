-- Cierra préstamo/recarga/alquiler/GRE pendientes ligados al CPE y suelta cilindros.
CREATE OR REPLACE FUNCTION ven_cerrar_custodia_comprobante(
    p_id_comprobante INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_alquiler RECORD;
    v_alq_det RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    -- Préstamos: devolver cilindros pendientes y cerrar cabecera
    FOR v_prestamo IN
        SELECT id FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        FOR v_detalle IN
            SELECT id FROM bal_prestamo_detalle
            WHERE estado = 1 AND id_prestamo = v_prestamo.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_prestamo_detalle(
                v_detalle.id,
                CURRENT_DATE,
                NULL,
                p_id_usuario,
                'VACIO',
                'Devolución automática por anulación/NC del comprobante'
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

    -- Recargas mostrador: devolver el gas a pro_stock y soltar el balón (inv_movimiento)
    FOR v_recarga IN
        SELECT id, id_balon
        FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id_comprobante
    LOOP
        v_result := inv_revertir_por_documento('RECARGA', v_recarga.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);

        UPDATE bal_movimiento_recarga
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE id = v_recarga.id AND estado = 1;
    END LOOP;

    -- Alquileres: reingreso de regulador y cilindros de detalle
    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            'Devolución automática por anulación/NC del comprobante',
            NULL,
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

        FOR v_alq_det IN
            SELECT id FROM bal_alquiler_detalle
            WHERE estado = 1 AND id_alquiler = v_alquiler.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_alquiler_detalle(v_alq_det.id, CURRENT_DATE, NULL, p_id_usuario);
            PERFORM ven_raise_si_error(v_result);
        END LOOP;

        SELECT lo.id INTO v_id_estado_final
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, CURRENT_DATE),
            id_estado = COALESCE(v_id_estado_final, id_estado),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_alquiler.id AND estado = 1;
    END LOOP;

    -- GRE PENDIENTE que referencia este CPE
    FOR v_guia IN
        SELECT DISTINCT g.id
        FROM gre_guia_remision g
        INNER JOIN gre_documentos_referencia r ON r.id_guia_remision = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
    LOOP
        v_result := gre_eliminar_guia_remision(v_guia.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Mantenimiento no finalizado ligado al CPE
    FOR v_mant IN
        SELECT m.id, m.id_balon, em.nombre AS nombre_estado
        FROM bal_mantenimiento m
        LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
        WHERE m.estado = 1 AND m.id_comprobante_venta = p_id_comprobante
    LOOP
        IF UPPER(COALESCE(v_mant.nombre_estado, '')) = 'FINALIZADO' THEN
            CONTINUE;
        END IF;

        UPDATE bal_mantenimiento
        SET
            estado = 0,
            id_comprobante_venta = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_mant.id AND estado = 1;

        SELECT lo.id INTO v_id_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon b
        SET
            id_estado_balon = COALESCE(v_id_en_almacen, b.id_estado_balon),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.id = v_mant.id_balon
          AND b.estado = 1
          AND EXISTS (
              SELECT 1 FROM gen_lista_opciones eb
              WHERE eb.id = b.id_estado_balon
                AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
          );
    END LOOP;

    -- Garantía sin reembolsos: se da de baja el cobro documental (el efectivo iba en el CPE)
    UPDATE ven_garantia_movimiento gm
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE gm.estado = 1
      AND gm.id_comprobante = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1
          FROM ven_garantia_movimiento d
          INNER JOIN gen_lista_opciones td ON td.id = d.id_tipo_movimiento
          WHERE d.id_garantia = gm.id_garantia
            AND d.estado = 1
            AND UPPER(td.nombre) = 'DEVOLUCION'
      );

    UPDATE ven_garantia g
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE g.estado = 1
      AND COALESCE(g.monto_devuelto, 0) = 0
      AND NOT EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm
          WHERE gm.id_garantia = g.id AND gm.estado = 1
      )
      AND EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm0
          WHERE gm0.id_garantia = g.id AND gm0.id_comprobante = p_id_comprobante
      );
END;
$function$;
