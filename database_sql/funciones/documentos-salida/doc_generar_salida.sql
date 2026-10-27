-- Genera un documento de salida y registra sus movimientos de inventario
DROP FUNCTION IF EXISTS public.doc_generar_salida (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.doc_generar_salida (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_doc RECORD;
    v_estado VARCHAR;
    v_tipo VARCHAR;
    v_id_generada INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_id_mov INTEGER;
    v_codigo_mov VARCHAR;
    v_n INTEGER := 0;
    v_id_pend_envio INTEGER;
    v_hay_balones BOOLEAN;
    v_prevuelo NUMERIC;
    v_exceso_gas TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    v_estado := v_doc.estado_ciclo;
    v_tipo := v_doc.tipo_orden;

    IF v_estado = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF v_estado IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    v_codigo_mov := CASE v_tipo
        WHEN 'RECARGA_PLANTA_EXTERNA' THEN 'SALIDA_PLANTA_EXTERNA'
        WHEN 'TRASLADO'               THEN 'TRASLADO'
        ELSE 'SALIDA_ENTREGA_CLIENTE'
    END;

    IF v_tipo = 'TRASLADO' AND v_doc.id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'El traslado requiere almacén de destino: regístralo antes de generar',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_generada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'GENERADA' AND lo.estado = 1;

    IF v_id_generada IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta el estado GENERADA en el catálogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    IF v_doc.id_venta IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM doc_salida_detalle WHERE id_doc_salida = p_id AND estado = 1) THEN
            RETURN json_build_object('error', 'El documento no tiene líneas que trasladar', 'registro', NULL);
        END IF;

        BEGIN
            SELECT COALESCE(SUM(doc_cantidad_linea_en_unidad_producto(dd.id)), 0)
            INTO v_prevuelo
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1;

            IF v_tipo = 'RECARGA_PLANTA_EXTERNA' THEN
                SELECT string_agg(
                           format(
                               '%s (declarado %s %s, capacidad %s %s)',
                               t.nombre_producto,
                               TRIM(TO_CHAR(t.declarado, 'FM999999990.0999')),
                               COALESCE(t.unidad, ''),
                               TRIM(TO_CHAR(t.capacidad, 'FM999999990.0999')),
                               COALESCE(t.unidad, '')
                           ),
                           '; ' ORDER BY t.nombre_producto
                       )
                INTO v_exceso_gas
                FROM (
                    SELECT
                        dd.id_producto,
                        p.nombre AS nombre_producto,
                        um.nombre AS unidad,
                        SUM(doc_cantidad_linea_en_unidad_producto(dd.id)) AS declarado,
                        (
                            SELECT COALESCE(SUM(
                                inv_convertir_a_unidad_producto(
                                    dd.id_producto, tb.capacidad, tb.id_unidad_medida
                                )
                            ), 0)
                            FROM doc_salida_detalle db
                            JOIN bal_balon b ON b.id = db.id_balon
                            JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                            WHERE db.id_doc_salida = p_id
                              AND db.estado = 1
                              AND db.id_balon IS NOT NULL
                              AND COALESCE(b.id_producto_gas, tb.id_gas) = dd.id_producto
                              AND COALESCE(tb.capacidad, 0) > 0
                        ) AS capacidad
                    FROM doc_salida_detalle dd
                    JOIN pro_producto p ON p.id = dd.id_producto
                    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
                    WHERE dd.id_doc_salida = p_id
                      AND dd.estado = 1
                      AND dd.id_balon IS NULL
                      AND dd.cantidad > 0
                    GROUP BY dd.id_producto, p.nombre, um.nombre
                ) t
                WHERE t.capacidad > 0
                  AND ROUND(t.declarado, 2) > ROUND(t.capacidad, 2);

                IF v_exceso_gas IS NOT NULL THEN
                    RETURN json_build_object(
                        'error', format(
                            'El gas declarado supera la capacidad de los cilindros de la orden: %s. Corrige el detalle antes de generar.',
                            v_exceso_gas
                        ),
                        'registro', NULL
                    );
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RETURN json_build_object(
                'error', format('No se puede generar la salida: %s', SQLERRM),
                'registro', NULL
            );
        END;

        IF v_tipo NOT IN ('RECARGA_PLANTA_EXTERNA', 'TRASLADO') THEN
            SELECT EXISTS (
                SELECT 1
                FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = p_id
                  AND dd.estado = 1
                  AND dd.id_balon IS NOT NULL
            ) INTO v_hay_balones;

            IF v_hay_balones THEN
                SELECT lo.id INTO v_id_pend_envio
                FROM gen_lista_opciones lo
                JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'EstadoBalon'
                  AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO'
                  AND lo.estado = 1
                LIMIT 1;

                IF v_id_pend_envio IS NULL THEN
                    RETURN json_build_object(
                        'error', 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon',
                        'registro', NULL
                    );
                END IF;
            END IF;
        END IF;

        FOR v_det IN
            SELECT
                dd.*,
                doc_cantidad_linea_en_unidad_producto(dd.id) AS cantidad_movimiento
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
            ORDER BY dd.item
        LOOP
            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => CASE WHEN v_det.id_balon IS NOT NULL THEN 'BALON' ELSE 'PRODUCTO' END,
                p_codigo_tipo_movimiento       => v_codigo_mov,
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => COALESCE(v_det.cantidad_movimiento, v_det.cantidad),
                p_id_almacen_origen            => v_doc.id_almacen,
                p_id_almacen_destino           => v_doc.id_almacen_destino,
                p_id_cliente                   => COALESCE(v_doc.id_destinatario, v_doc.id_cliente, v_doc.id_proveedor),
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id,
                p_glosa                        => format('Salida por orden %s', v_doc.numero),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;

            IF COALESCE((v_mov->>'creado')::BOOLEAN, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registró el movimiento de la línea % (duplicado)', v_det.item;
            END IF;

            v_id_mov := (v_mov->'registro'->>'id')::INTEGER;

            UPDATE doc_salida_detalle
            SET id_movimiento = v_id_mov,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id;

            v_n := v_n + 1;
        END LOOP;

        IF v_id_pend_envio IS NOT NULL THEN
            UPDATE bal_balon b
            SET id_estado_balon = v_id_pend_envio,
                id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
                id_cliente_ubicacion = NULL,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id
              AND dd.estado = 1
              AND dd.id_balon = b.id
              AND b.estado = 1
              AND UPPER(COALESCE(
                    (SELECT lo2.nombre FROM gen_lista_opciones lo2 WHERE lo2.id = b.id_estado_balon),
                    ''
                  )) NOT IN ('DADO_DE_BAJA', 'ROBO');
        END IF;
    END IF;

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_generada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
