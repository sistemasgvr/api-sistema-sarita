BEGIN;
CREATE OR REPLACE FUNCTION public.ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_alquiler RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
    v_ref_origen VARCHAR;
    v_id_nc INTEGER;
    v_ref_nc VARCHAR;
    v_glosa VARCHAR(300);
    v_balon RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    -- Texto que verá el historial del cilindro: qué documento lo devolvió.
    SELECT c.serie || '-' || c.numero INTO v_ref_origen
    FROM ven_comprobante c WHERE c.id = p_id_comprobante;

    SELECT nc.id, nc.serie || '-' || nc.numero
    INTO v_id_nc, v_ref_nc
    FROM ven_comprobante nc
    INNER JOIN gen_lista_opciones tc ON tc.id = nc.id_tipo_comprobante AND tc.descripcion = '07'
    LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
    WHERE nc.id_comprobante_origen = p_id_comprobante
      AND nc.estado = 1
      AND COALESCE(es.nombre, '') NOT IN ('RECHAZADO', 'BAJA')
    ORDER BY (COALESCE(es.nombre, '') = 'ACEPTADO') DESC, nc.id DESC
    LIMIT 1;

    v_glosa := LEFT(CASE
        WHEN v_id_nc IS NOT NULL THEN
            format('Retorno por nota de crédito %s (anula %s)', v_ref_nc, COALESCE(v_ref_origen, '#' || p_id_comprobante))
        ELSE
            format('Retorno por anulación del comprobante %s', COALESCE(v_ref_origen, '#' || p_id_comprobante))
    END, 300);

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
                v_glosa
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

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

    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            v_glosa,
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

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

    FOR v_guia IN
        SELECT DISTINCT g.id, c.serie, c.numero
        FROM doc_salida g
        INNER JOIN doc_salida_referencia r ON r.id_doc_salida = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        INNER JOIN gen_lista_opciones ec ON ec.id = g.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND ec.nombre <> 'ANULADA'
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
          AND NOT COALESCE(g.emitido_sunat, FALSE)
    LOOP
        v_result := doc_anular_salida(v_guia.id, v_glosa, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

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
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
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

    -- Cilindros del comprobante que ya quedaron DISPONIBLES en almacén pero
    -- cuyo último movimiento vigente sigue siendo una salida: pasa cuando el
    -- cilindro estaba PENDIENTE_ENVIO / EN_TRANSITO (la devolución del
    -- préstamo se omite y doc_anular_salida lo libera sin movimiento). Sin
    -- esta entrada el historial muestra "Salida préstamo" como último hecho.
    FOR v_balon IN
        SELECT b.id, b.id_almacen, ult.id_cliente
        FROM bal_balon b
        INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon AND eb.nombre = 'DISPONIBLE'
        CROSS JOIN LATERAL (
            SELECT m.id_tipo_movimiento, m.id_cliente
            FROM inv_movimiento m
            WHERE m.estado = 1 AND m.naturaleza = 'BALON' AND m.id_balon = b.id
            ORDER BY m.fecha DESC, m.id DESC
            LIMIT 1
        ) ult
        WHERE b.estado = 1
          AND b.id_almacen IS NOT NULL
          AND COALESCE(inv_signo_tipo_movimiento(ult.id_tipo_movimiento), 0) < 0
          AND b.id IN (
              SELECT pd.id_balon
              FROM bal_prestamo pr
              INNER JOIN bal_prestamo_detalle pd ON pd.id_prestamo = pr.id AND pd.estado = 1
              WHERE pr.estado = 1 AND pr.id_comprobante_venta = p_id_comprobante
                AND pd.id_balon IS NOT NULL
              UNION
              SELECT vd.id_balon
              FROM ven_comprobante_detalle vd
              WHERE vd.id_comprobante = p_id_comprobante
                AND vd.estado = 1
                AND vd.id_balon IS NOT NULL
          )
    LOOP
        v_result := inv_registrar_movimiento(
            p_naturaleza                   => 'BALON',
            p_codigo_tipo_movimiento       => 'ENTRADA_DEVOLUCION',
            p_fecha                        => LOCALTIMESTAMP,
            p_id_balon                     => v_balon.id,
            p_cantidad                     => 1,
            p_id_almacen_destino           => v_balon.id_almacen,
            p_id_cliente                   => v_balon.id_cliente,
            p_codigo_tipo_documento_origen => CASE WHEN v_id_nc IS NOT NULL THEN 'NOTA_CREDITO' ELSE NULL END,
            p_id_documento_origen          => v_id_nc,
            p_glosa                        => v_glosa,
            p_id_usuario_auditoria         => p_id_usuario,
            p_forzar                       => TRUE
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

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
$function$
;
COMMIT;
