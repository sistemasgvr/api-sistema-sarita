-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
-- Actualizada por database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql:
--   el retorno se registra en dos planos, igual que la salida. La línea del
--   balón mueve SOLO el envase (antes ingresaba 1 unidad de gas por cilindro,
--   sin entrada consolidada). El gas ingresa consolidado por producto con la
--   cantidad de la factura de compra vinculada (o, sin factura, con las líneas
--   de gas del propio documento). Además, un guard impide registrar dos veces
--   el retorno de la misma orden.
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_usuario_auditoria integer);

-- p_lote / p_fecha_vencimiento_lote / p_fecha_prueba_hidrostatica: antes los
-- llenaba bal_actualizar_recarga_planta (eliminada en la unificación a
-- doc_salida). Es el mismo paso del flujo — registrar el retorno — así que
-- se agregan aquí en vez de crear otra función.
-- p_id_lote_protocolo (Fase 5): ficha ICP con la que volvieron los cilindros.
-- Va al final de la firma para no romper las llamadas posicionales existentes.
CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer DEFAULT NULL::integer, p_guardar_balones_almacen boolean DEFAULT false, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_lote_protocolo integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_id_documento_ref INTEGER;
    v_codigo_doc VARCHAR;
    v_id_compra INTEGER;
    v_hay_gas_compra BOOLEAN := FALSE;
    v_det RECORD;
    v_gas RECORD;
    v_mov JSON;
    v_id_balones INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM doc_salida WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    -- Guard de doble retorno: si algún cilindro de esta orden ya tiene una
    -- ENTRADA_PLANTA_EXTERNA activa, el retorno ya se registró (desde el
    -- documento de salida o desde la compra) y no se vuelve a mover inventario.
    -- Va antes del UPDATE de cabecera para que un reenvío no deje la orden con
    -- fecha/almacén distintos a los de los movimientos ya hechos. Al anular
    -- (inv_revertir_por_documento) los movimientos quedan con estado = 0, así
    -- que después de una anulación el retorno sí se puede volver a registrar.
    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_tipo_entrada_planta
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
          AND lo.estado = 1
        LIMIT 1;

        IF EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN doc_salida_detalle d ON d.id = m.id_documento_detalle
            WHERE m.estado = 1
              AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
              AND m.naturaleza = 'BALON'
              AND d.id_doc_salida = p_id_recarga_planta
              AND d.id_balon IS NOT NULL
              AND m.id_balon = d.id_balon
        ) THEN
            RETURN json_build_object(
                'error', 'El retorno de esta orden ya fue registrado; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Datos del retorno sobre el propio documento.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        fecha_retorno = COALESCE(p_fecha_llegada_almacen, fecha_retorno),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_lote_protocolo = COALESCE(p_id_lote_protocolo, id_lote_protocolo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_recarga_planta;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        -- Compra vinculada: la que llega por parámetro o la que la orden ya
        -- tenía (factura registrada antes que el retorno).
        v_id_compra := COALESCE(
            p_id_comprobante_compra,
            (SELECT id_comprobante_compra FROM doc_salida WHERE id = p_id_recarga_planta)
        );

        -- Con factura vinculada el documento de referencia es la compra; si no,
        -- la orden. Envases y gas se etiquetan igual, así com_anular_compra
        -- (COMPRA) y com_revertir_cilindros_recarga_compra / doc_anular_salida
        -- (ORDEN_SALIDA) revierten el retorno completo.
        IF v_id_compra IS NOT NULL THEN
            v_id_documento_ref := v_id_compra;
            v_codigo_doc := 'COMPRA';
        ELSE
            v_id_documento_ref := p_id_recarga_planta;
            v_codigo_doc := 'ORDEN_SALIDA';
        END IF;

        -- ------------------------------------------------------------
        -- 1) Envases: una línea por cilindro. Mueve SOLO el envase (custodia
        --    DISPONIBLE + LLENO en el almacén de llegada), igual que la línea
        --    del balón en la salida. El gas NO va aquí: la línea del balón tiene
        --    cantidad 1 y tomar su gas ingresaba 1 unidad por cilindro.
        -- ------------------------------------------------------------
        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon
            FROM doc_salida_detalle d
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
            ORDER BY d.item
        LOOP
            v_id_balones := v_id_balones || v_det.id_balon;

            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'BALON',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => NULL,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => 1,
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => v_codigo_doc,
                p_id_documento_origen          => v_id_documento_ref,
                p_glosa                        => format(
                    'Entrada por recarga en planta externa (orden #%s)', p_id_recarga_planta
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada del balón %: %',
                    v_det.id_balon, v_mov->>'error';
            END IF;
        END LOOP;

        -- ------------------------------------------------------------
        -- 2) Gas: consolidado por producto, con la cantidad que realmente
        --    ingresa. Naturaleza PRODUCTO: el almacén que recibe el stock es
        --    p_id_almacen_origen (mismo criterio que el INGRESO de compra y que
        --    inv_revertir_por_documento). Si el movimiento ya existía
        --    ('creado' = false) se sigue sin error: es idempotente.
        --
        --    2a) Con compra vinculada: la cantidad facturada por cada línea de
        --        gas de la compra. Se etiqueta COMPRA + id de la compra con
        --        id_documento_detalle = línea de compra, así com_anular_compra
        --        la revierte con inv_revertir_por_documento('COMPRA', ...).
        -- ------------------------------------------------------------
        v_hay_gas_compra := FALSE;

        IF v_id_compra IS NOT NULL THEN
            FOR v_gas IN
                SELECT
                    cd.id AS id_detalle,
                    cd.id_producto,
                    inv_convertir_a_unidad_producto(
                        cd.id_producto,
                        cd.cantidad,
                        cd.id_unidad_medida
                    ) AS cantidad
                FROM com_comprobante_compra_detalle cd
                JOIN com_comprobante_compra c ON c.id = cd.id_comprobante
                JOIN pro_producto p ON p.id = cd.id_producto
                WHERE cd.id_comprobante = v_id_compra
                  AND c.estado = 1
                  AND cd.estado = 1
                  AND COALESCE(p.es_gas, FALSE) = TRUE
                ORDER BY cd.item
            LOOP
                v_hay_gas_compra := TRUE;

                v_mov := inv_registrar_movimiento(
                    p_naturaleza                   => 'PRODUCTO',
                    p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                    p_fecha                        => LOCALTIMESTAMP,
                    p_id_producto                  => v_gas.id_producto,
                    p_id_balon                     => NULL,
                    p_cantidad                     => v_gas.cantidad,
                    p_id_almacen_origen            => p_id_almacen,
                    p_id_almacen_destino           => NULL,
                    p_id_cliente                   => p_id_proveedor,
                    p_codigo_tipo_documento_origen => 'COMPRA',
                    p_id_documento_origen          => v_id_compra,
                    p_glosa                        => format(
                        'Entrada de gas por recarga en planta externa (compra #%s, orden #%s)',
                        v_id_compra, p_id_recarga_planta
                    ),
                    p_id_usuario_auditoria         => p_id_usuario_auditoria,
                    p_id_documento_detalle         => v_gas.id_detalle
                );

                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION 'No se pudo registrar la entrada de gas del producto % (compra #%): %',
                        v_gas.id_producto, v_id_compra, v_mov->>'error';
                END IF;
            END LOOP;
        END IF;

        -- ------------------------------------------------------------
        --    2b) Fallback, cuando el retorno se registra antes que la factura
        --        (o la compra vinculada no tiene líneas de gas): se ingresa lo
        --        que declaró el propio documento en sus líneas de gas (línea por
        --        producto, id_balon NULL), etiquetado ORDEN_SALIDA + id de la
        --        orden. Distinto id_tipo_movimiento que la SALIDA de la misma
        --        línea, así que no choca con la idempotencia de la salida.
        -- ------------------------------------------------------------
        IF NOT v_hay_gas_compra THEN
            FOR v_gas IN
                SELECT
                    d.id AS id_detalle,
                    d.id_producto,
                    inv_convertir_a_unidad_producto(
                        d.id_producto,
                        d.cantidad,
                        d.id_unidad_medida
                    ) AS cantidad
                FROM doc_salida_detalle d
                WHERE d.id_doc_salida = p_id_recarga_planta
                  AND d.estado = 1
                  AND d.id_producto IS NOT NULL
                  AND d.id_balon IS NULL
                ORDER BY d.item
            LOOP
                v_mov := inv_registrar_movimiento(
                    p_naturaleza                   => 'PRODUCTO',
                    p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                    p_fecha                        => LOCALTIMESTAMP,
                    p_id_producto                  => v_gas.id_producto,
                    p_id_balon                     => NULL,
                    p_cantidad                     => v_gas.cantidad,
                    p_id_almacen_origen            => p_id_almacen,
                    p_id_almacen_destino           => NULL,
                    p_id_cliente                   => p_id_proveedor,
                    p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                    p_id_documento_origen          => p_id_recarga_planta,
                    p_glosa                        => format(
                        'Entrada de gas por recarga en planta externa (orden #%s)', p_id_recarga_planta
                    ),
                    p_id_usuario_auditoria         => p_id_usuario_auditoria,
                    p_id_documento_detalle         => v_gas.id_detalle
                );

                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION 'No se pudo registrar la entrada de gas del producto % (orden #%): %',
                        v_gas.id_producto, p_id_recarga_planta, v_mov->>'error';
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Fase 5: los cilindros que volvieron quedan con esta ficha como vigente.
    IF p_id_lote_protocolo IS NOT NULL AND array_length(v_id_balones, 1) IS NOT NULL THEN
        PERFORM bal_aplicar_lote_protocolo_balones(
            p_id_lote_protocolo,
            array_to_json(v_id_balones),
            p_id_usuario_auditoria
        );
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta
    ));
END;
$function$;
