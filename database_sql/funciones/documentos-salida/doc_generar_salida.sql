-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_generar_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
--
-- Para OS sin venta (id_venta IS NULL) de tipos compatibles con REPARTO, tras el
-- kardex se corrige custodia a PENDIENTE_ENVIO (ver bloque al final del loop).
DROP FUNCTION IF EXISTS doc_generar_salida(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_generar_salida(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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
        -- Ya produjo efectos; no se repiten.
        RETURN doc_obtener_salida(p_id);
    END IF;

    -- El tipo de movimiento depende del propósito del documento.
    v_codigo_mov := CASE v_tipo
        WHEN 'RECARGA_PLANTA_EXTERNA' THEN 'SALIDA_PLANTA_EXTERNA'
        WHEN 'TRASLADO'               THEN 'TRASLADO'
        ELSE 'SALIDA_ENTREGA_CLIENTE'
    END;

    -- Se comprueba acá y no solo al crear: hay órdenes anteriores a que el
    -- destino existiera, y sin él inv_registrar_movimiento aborta con una
    -- excepción que tumba toda la petición en vez de devolver el error.
    IF v_tipo = 'TRASLADO' AND v_doc.id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'El traslado requiere almacén de destino: regístralo antes de generar',
            'registro', NULL
        );
    END IF;

    IF v_doc.id_venta IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM doc_salida_detalle WHERE id_doc_salida = p_id AND estado = 1) THEN
            RETURN json_build_object('error', 'El documento no tiene líneas que trasladar', 'registro', NULL);
        END IF;

        -- Custodia REPARTO (OS sin venta): validar catálogo ANTES del kardex.
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
            SELECT dd.*
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
            ORDER BY dd.item
        LOOP
            -- El gas viaja SIEMPRE en sus propias líneas de producto, nunca en
            -- la del cilindro. El detalle se arma en dos planos: una línea por
            -- balón, que mueve el envase (estado y almacén), y una línea por
            -- producto con la cantidad total de gas que sale. Tomar además el
            -- gas del balón descontaría el mismo gas dos veces.
            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => CASE WHEN v_det.id_balon IS NOT NULL THEN 'BALON' ELSE 'PRODUCTO' END,
                p_codigo_tipo_movimiento       => v_codigo_mov,
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => v_det.cantidad,
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

        -- ------------------------------------------------------------
        -- Custodia REPARTO (OS sin venta, tipos de entrega a cliente)
        --
        -- TRADEOFF: se mantiene SALIDA_ENTREGA_CLIENTE en inv_registrar_movimiento
        -- (kardex + auditoría del movimiento). Ese tipo pone EN_PODER_CLIENTE y
        -- limpia id_almacen —demasiado temprano para el flujo age_* (iniciar →
        -- EN_TRANSITO, culminar → EN_PODER_CLIENTE), que exige PENDIENTE_ENVIO.
        -- Cambiar el TipoMovInvUnificado / el CASE de estados en
        -- inv_registrar_movimiento es más riesgoso (afecta otros callers).
        -- Corrección local: tras generar, los cilindros de la OS vuelven a
        -- PENDIENTE_ENVIO y al almacén de la orden. TRASLADO y
        -- RECARGA_PLANTA_EXTERNA no pasan por REPARTO y no se tocan.
        -- ------------------------------------------------------------
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
    -- Con id_venta no se toca inventario: el movimiento lo creó la venta y este
    -- documento solo lo respalda documentalmente (apunte 1.c.iv.6).

    SELECT lo.id INTO v_id_generada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'GENERADA' AND lo.estado = 1;

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_generada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
