-- Ajusta el gas ingresado por el retorno de una recarga en planta externa
DROP FUNCTION IF EXISTS public.bal_sincronizar_gas_retorno_planta (
  p_id_doc_salida integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.bal_sincronizar_gas_retorno_planta (
  p_id_doc_salida integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_orden RECORD;
    v_id_tipo_entrada_planta INTEGER;
    v_retorno_registrado BOOLEAN;
    v_id_compra INTEGER;
    v_origen VARCHAR := NULL;
    v_gas RECORD;
    v_mov JSON;
    v_rev JSON;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id, COALESCE(d.id_almacen_retorno, d.id_almacen) AS id_almacen,
           d.id_proveedor, d.fecha_llegada_almacen,
           c.id AS id_compra_activa
    INTO v_orden
    FROM doc_salida d
    LEFT JOIN com_comprobante_compra c
        ON c.id = d.id_comprobante_compra AND c.estado = 1
    WHERE d.id = p_id_doc_salida AND d.estado = 1
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La orden de recarga en planta externa #% no existe o está anulada', p_id_doc_salida;
    END IF;

    SELECT lo.id INTO v_id_tipo_entrada_planta
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_entrada_planta IS NULL THEN
        RAISE EXCEPTION 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM inv_movimiento m
        JOIN doc_salida_detalle dd ON dd.id = m.id_documento_detalle
        WHERE m.estado = 1
          AND m.naturaleza = 'BALON'
          AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
          AND dd.id_doc_salida = p_id_doc_salida
          AND dd.id_balon IS NOT NULL
          AND m.id_balon = dd.id_balon
    ) INTO v_retorno_registrado;

    IF NOT v_retorno_registrado THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('sincronizado', FALSE, 'origen', NULL, 'movimientos', 0)
        );
    END IF;

    IF v_orden.id_almacen IS NULL THEN
        RAISE EXCEPTION 'La orden #% no tiene almacén de llegada; no se puede ingresar el gas del retorno', p_id_doc_salida;
    END IF;

    v_id_compra := v_orden.id_compra_activa;

    v_rev := inv_revertir_por_documento(
        'ORDEN_SALIDA', p_id_doc_salida, p_id_usuario_auditoria,
        NULL, 'ENTRADA_PLANTA_EXTERNA', 'PRODUCTO'
    );
    IF v_rev->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'No se pudo ajustar el gas del retorno de la orden #%: %', p_id_doc_salida, v_rev->>'error';
    END IF;

    IF v_id_compra IS NOT NULL THEN
        v_rev := inv_revertir_por_documento(
            'COMPRA', v_id_compra, p_id_usuario_auditoria,
            NULL, 'ENTRADA_PLANTA_EXTERNA', 'PRODUCTO'
        );
        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo ajustar el gas del retorno de la orden #% (compra #%): %', p_id_doc_salida, v_id_compra, v_rev->>'error';
        END IF;
    END IF;

    IF v_id_compra IS NOT NULL THEN
        FOR v_gas IN
            SELECT
                cd.id AS id_detalle,
                cd.id_producto,
                inv_convertir_a_unidad_producto(cd.id_producto, cd.cantidad, cd.id_unidad_medida) AS cantidad
            FROM com_comprobante_compra_detalle cd
            JOIN pro_producto p ON p.id = cd.id_producto
            WHERE cd.id_comprobante = v_id_compra
              AND cd.estado = 1
              AND COALESCE(p.es_gas, FALSE) = TRUE
              AND cd.cantidad > 0
            ORDER BY cd.item
        LOOP
            v_origen := 'COMPRA';

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'PRODUCTO',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_gas.id_producto,
                p_id_balon                     => NULL,
                p_cantidad                     => v_gas.cantidad,
                p_id_almacen_origen            => v_orden.id_almacen,
                p_id_almacen_destino           => NULL,
                p_id_cliente                   => v_orden.id_proveedor,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen          => v_id_compra,
                p_glosa                        => format(
                    'Entrada de gas por recarga en planta externa (compra #%s, orden #%s)',
                    v_id_compra, p_id_doc_salida
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_gas.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada de gas del producto % (compra #%): %',
                    v_gas.id_producto, v_id_compra, v_mov->>'error';
            END IF;

            v_n := v_n + 1;
        END LOOP;
    END IF;

    IF v_origen IS NULL THEN
        FOR v_gas IN
            SELECT
                dd.id AS id_detalle,
                dd.id_producto,
                inv_convertir_a_unidad_producto(dd.id_producto, dd.cantidad, dd.id_unidad_medida) AS cantidad
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id_doc_salida
              AND dd.estado = 1
              AND dd.id_producto IS NOT NULL
              AND dd.id_balon IS NULL
              AND dd.cantidad > 0
            ORDER BY dd.item
        LOOP
            v_origen := 'ORDEN_SALIDA';

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'PRODUCTO',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_gas.id_producto,
                p_id_balon                     => NULL,
                p_cantidad                     => v_gas.cantidad,
                p_id_almacen_origen            => v_orden.id_almacen,
                p_id_almacen_destino           => NULL,
                p_id_cliente                   => v_orden.id_proveedor,
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id_doc_salida,
                p_glosa                        => format(
                    'Entrada de gas por recarga en planta externa (orden #%s)', p_id_doc_salida
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_gas.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada de gas del producto % (orden #%): %',
                    v_gas.id_producto, p_id_doc_salida, v_mov->>'error';
            END IF;

            v_n := v_n + 1;
        END LOOP;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('sincronizado', TRUE, 'origen', v_origen, 'movimientos', v_n)
    );
END;
$function$;
