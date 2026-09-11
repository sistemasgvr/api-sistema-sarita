-- ============================================================
-- Migracion Wave1 restante: TRASLADO+BALON sin gas + candado bal_finalizar vs recojo
-- Fecha: 2026-09-11
-- (NC/devolver/doc_anular estan en 20260911_w1_nc_planta_devolver.sql)
-- Aplicar: node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_w1_traslado_planta.sql
-- ============================================================


-- ===== database_sql/funciones/inventario-movimientos/inv_registrar_movimiento.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_registrar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- todo fallo posterior a una mutación de inventario es RAISE (rollback). El
-- stock insuficiente de gas se detectaba con bal_balon ya actualizado y se
-- devolvía soft, dejando el cilindro movido sin su gas.
-- Actualizada por database_sql/migraciones/20260911_w1_planta_retorno_traslado_gas.sql:
-- naturaleza BALON + TRASLADO / TRASLADO_LIMA con id_producto y cantidad > 0 se
-- rechaza: el gas de un traslado se descontaba del origen y no entraba en el
-- destino. El rechazo es previo a cualquier mutación, así que es error soft.
DROP FUNCTION IF EXISTS inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_id_almacen_origen integer, p_id_almacen_destino integer, p_id_cliente integer, p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_glosa character varying, p_id_usuario_auditoria integer, p_id_movimiento_padre integer, p_sentido_ajuste character varying, p_forzar boolean, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone DEFAULT now(), p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_cantidad numeric DEFAULT 0, p_id_almacen_origen integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_codigo_tipo_documento_origen character varying DEFAULT NULL::character varying, p_id_documento_origen integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_movimiento_padre integer DEFAULT NULL::integer, p_sentido_ajuste character varying DEFAULT NULL::character varying, p_forzar boolean DEFAULT false, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_naturaleza VARCHAR;
    v_id_tipo_mov INTEGER;
    v_nombre_tipo_mov VARCHAR;
    v_id_tipo_doc INTEGER;
    v_id_existente INTEGER;
    v_cantidad NUMERIC(12,4);
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_signo INTEGER;
    v_id INTEGER;
    -- rama PRODUCTO
    v_afecta_stock BOOLEAN;
    v_id_unidad_medida INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    -- rama BALON
    v_nombre_estado_actual VARCHAR;
    v_codigo_estado_destino VARCHAR;
    v_cliente_destino INTEGER;
    v_limpiar_almacen BOOLEAN;
    v_codigo_contenido VARCHAR;
    v_id_estado_balon INTEGER;
    v_id_almacen_balon INTEGER;
    v_id_estado_anterior INTEGER;
    v_id_cliente_anterior INTEGER;
    v_id_almacen_anterior INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_naturaleza := UPPER(TRIM(COALESCE(p_naturaleza, '')));
    IF v_naturaleza NOT IN ('PRODUCTO', 'BALON') THEN
        RETURN json_build_object('error', 'naturaleza debe ser PRODUCTO o BALON', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'PRODUCTO' AND p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'id_producto es obligatorio para naturaleza PRODUCTO', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'BALON' AND p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'id_balon es obligatorio para naturaleza BALON', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_movimiento IS NULL OR TRIM(p_codigo_tipo_movimiento) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.id, lo.nombre INTO v_id_tipo_mov, v_nombre_tipo_mov
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_mov IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento))),
            'registro', NULL
        );
    END IF;

    IF p_codigo_tipo_documento_origen IS NOT NULL AND TRIM(p_codigo_tipo_documento_origen) <> '' THEN
        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_documento_origen))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc IS NULL THEN
            RETURN json_build_object(
                'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(p_codigo_tipo_documento_origen))),
                'registro', NULL
            );
        END IF;
    END IF;
    IF p_id_documento_origen IS NOT NULL AND v_id_tipo_doc IS NOT NULL AND NOT COALESCE(p_forzar, FALSE) THEN
        SELECT m.id INTO v_id_existente
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.naturaleza = v_naturaleza
          AND m.id_tipo_documento_origen = v_id_tipo_doc
          AND m.id_documento_origen = p_id_documento_origen
          AND COALESCE(m.id_documento_detalle, -1) = COALESCE(p_id_documento_detalle, -1)
          AND m.id_tipo_movimiento = v_id_tipo_mov
          AND (v_naturaleza <> 'PRODUCTO' OR m.id_producto = p_id_producto)
          AND (v_naturaleza <> 'BALON' OR m.id_balon = p_id_balon)
        ORDER BY m.id
        LIMIT 1;

        IF v_id_existente IS NOT NULL THEN
            RETURN (inv_obtener_movimiento(v_id_existente)::JSONB || jsonb_build_object('creado', FALSE))::JSON;
        END IF;
    END IF;

    v_cantidad := ABS(COALESCE(p_cantidad, 0));
    v_es_traslado := (v_naturaleza = 'PRODUCTO' AND UPPER(v_nombre_tipo_mov) = 'TRASLADO');
    v_signo := inv_signo_tipo_movimiento(v_id_tipo_mov);

    IF UPPER(v_nombre_tipo_mov) = 'AJUSTE' THEN
        IF UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) NOT IN ('MAS', 'MENOS') THEN
            RETURN json_build_object('error', 'El ajuste requiere sentido MAS o MENOS', 'registro', NULL);
        END IF;
        v_es_salida := UPPER(TRIM(p_sentido_ajuste)) = 'MENOS';
    ELSIF v_signo IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no tiene signo configurado', v_nombre_tipo_mov),
            'registro', NULL
        );
    ELSE
        v_es_salida := v_signo < 0 OR v_es_traslado;
    END IF;

    -- Un traslado de cilindros mueve envases entre almacenes; el gas que llevan
    -- dentro no cambia de saldo. Con id_producto en la línea del balón, el
    -- bloque de gas de más abajo lo descontaba del origen sin reponerlo en el
    -- destino (naturaleza BALON no tiene rama de traslado de stock), así que
    -- cada traslado evaporaba el contenido de los cilindros. El gas va en sus
    -- propias líneas de producto, como ya documenta doc_generar_salida.
    IF v_naturaleza = 'BALON'
       AND UPPER(v_nombre_tipo_mov) IN ('TRASLADO', 'TRASLADO_LIMA')
       AND p_id_producto IS NOT NULL
       AND v_cantidad > 0 THEN
        RETURN json_build_object(
            'error', format(
                'El gas no puede moverse en la línea del cilindro de un %s: regístralo en una línea de producto',
                UPPER(v_nombre_tipo_mov)
            ),
            'registro', NULL
        );
    END IF;

    IF v_naturaleza = 'PRODUCTO' THEN
        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
            RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF p_id_almacen_origen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_origen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(afecta_stock, FALSE), id_unidad_medida
        INTO v_afecta_stock, v_id_unidad_medida
        FROM pro_producto WHERE id = p_id_producto;

        IF v_es_traslado THEN
            IF p_id_almacen_destino IS NULL THEN
                RETURN json_build_object('error', 'El traslado requiere almacén de destino', 'registro', NULL);
            END IF;
            IF p_id_almacen_destino = p_id_almacen_origen THEN
                RETURN json_build_object('error', 'El almacén de destino debe ser distinto al de origen', 'registro', NULL);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
                RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registro', NULL);
            END IF;
        END IF;

        v_stock_anterior := 0;
        v_stock_nuevo := 0;

        IF v_afecta_stock THEN
            SELECT id, stock INTO v_id_stock, v_stock_anterior
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                -- Sin fila de stock el saldo es cero: la salida se rechaza aquí,
                -- antes de crear o reactivar la fila, para poder devolver el
                -- error soft sin dejar rastro.
                IF v_es_salida THEN
                    RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
                END IF;

                -- Soft-delete previo: UNIQUE(id_almacen, id_producto) bloquea INSERT.
                -- Reactivar como pro_crear_stock en vez de fallar.
                SELECT id INTO v_id_stock
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 0
                FOR UPDATE;

                IF v_id_stock IS NOT NULL THEN
                    UPDATE pro_stock
                    SET stock = 0,
                        estado = 1,
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id = v_id_stock;
                    v_stock_anterior := 0;
                ELSE
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (p_id_almacen_origen, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                END IF;
            END IF;

            IF v_es_salida THEN
                v_stock_nuevo := v_stock_anterior - v_cantidad;
            ELSE
                v_stock_nuevo := v_stock_anterior + v_cantidad;
            END IF;

            IF v_stock_nuevo < 0 THEN
                -- La fila de stock pudo crearse/reactivarse arriba: devolver un
                -- error soft dejaría ese cambio confirmado.
                RAISE EXCEPTION 'Stock insuficiente para registrar la salida';
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado THEN
                SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock_dest IS NULL THEN
                    SELECT id INTO v_id_stock_dest
                    FROM pro_stock
                    WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 0
                    FOR UPDATE;

                    IF v_id_stock_dest IS NOT NULL THEN
                        UPDATE pro_stock
                        SET stock = 0,
                            estado = 1,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_stock_dest;
                        v_stock_dest_ant := 0;
                    ELSE
                        INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                        VALUES (p_id_almacen_destino, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                        RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
                    END IF;
                END IF;

                UPDATE pro_stock
                SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock_dest;
            END IF;
        END IF;

        INSERT INTO inv_movimiento (
            fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad, id_unidad_medida,
            id_almacen_origen, id_almacen_destino, id_cliente,
            id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
            stock_anterior, stock_nuevo, glosa,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'PRODUCTO', p_id_producto, v_cantidad, v_id_unidad_medida,
            p_id_almacen_origen, p_id_almacen_destino, p_id_cliente,
            p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
            CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
            CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
            p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
    END IF;
    SELECT eb.nombre, b.id_almacen, b.id_estado_balon, b.id_cliente_ubicacion
    INTO v_nombre_estado_actual, v_id_almacen_balon, v_id_estado_anterior, v_id_cliente_anterior
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado_actual, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede registrar movimiento de un cilindro dado de baja o reportado como robo',
            'registro', NULL
        );
    END IF;

    v_id_almacen_anterior := v_id_almacen_balon;
    v_limpiar_almacen := FALSE;
    v_codigo_contenido := NULL;
    v_cliente_destino := NULL;
    CASE v_nombre_tipo_mov
        WHEN 'SALIDA_PRESTAMO' THEN
            v_codigo_estado_destino := 'PRESTADO_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ALQUILER' THEN
            v_codigo_estado_destino := 'ALQUILADO'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_VENTA' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_MANTENIMIENTO' THEN
            v_codigo_estado_destino := 'EN_MANTENIMIENTO'; v_cliente_destino := p_id_cliente;
        WHEN 'SALIDA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'EN_RECARGA_EXTERNA'; v_limpiar_almacen := TRUE; v_codigo_contenido := 'VACIO';
        WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
            v_codigo_estado_destino := 'DISPONIBLE';
        WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'DISPONIBLE'; v_codigo_contenido := 'LLENO';
        WHEN 'RECARGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'TRASLADO_LIMA' THEN
            v_codigo_estado_destino := 'EN_RUTA_LIMA'; v_limpiar_almacen := TRUE;
        ELSE
            v_codigo_estado_destino := NULL;
    END CASE;

    IF v_codigo_estado_destino IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_balon
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado_destino AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_balon IS NULL THEN
            RETURN json_build_object('error', format('Estado %s no configurado', v_codigo_estado_destino), 'registro', NULL);
        END IF;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_balon,
            id_cliente_ubicacion = CASE WHEN v_cliente_destino IS NOT NULL THEN v_cliente_destino ELSE NULL END,
            id_almacen = CASE
                WHEN v_limpiar_almacen THEN NULL
                ELSE COALESCE(p_id_almacen_destino, p_id_almacen_origen, id_almacen)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;

    ELSIF UPPER(v_nombre_tipo_mov) = 'TRASLADO' AND p_id_almacen_destino IS NOT NULL THEN
        -- Trasladar un cilindro cambia dónde está, no en qué situación está:
        -- sigue DISPONIBLE (o como estuviera), solo que en el otro almacén. Sin
        -- esto el traslado registraba el movimiento y dejaba el balón en el
        -- almacén de origen, que es justo lo que venía a cambiar.
        UPDATE bal_balon
        SET id_almacen = p_id_almacen_destino,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    -- Si el movimiento del balón también mueve gas, se refleja en pro_stock del gas.
    v_stock_anterior := NULL;
    v_stock_nuevo := NULL;
    IF p_id_producto IS NOT NULL AND v_cantidad > 0 THEN
        DECLARE
            v_id_almacen_gas INTEGER;
        BEGIN
            v_id_almacen_gas := COALESCE(
                CASE WHEN v_es_salida THEN p_id_almacen_origen ELSE p_id_almacen_destino END,
                p_id_almacen_origen, p_id_almacen_destino, v_id_almacen_balon
            );

            IF v_id_almacen_gas IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_anterior
                FROM pro_stock
                WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    SELECT id INTO v_id_stock
                    FROM pro_stock
                    WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 0
                    FOR UPDATE;

                    IF v_id_stock IS NOT NULL THEN
                        UPDATE pro_stock
                        SET stock = 0,
                            estado = 1,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_stock;
                        v_stock_anterior := 0;
                    ELSE
                        INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                        VALUES (v_id_almacen_gas, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                        RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                    END IF;
                END IF;

                IF v_es_salida THEN
                    v_stock_nuevo := v_stock_anterior - v_cantidad;
                ELSE
                    v_stock_nuevo := v_stock_anterior + v_cantidad;
                END IF;

                IF v_stock_nuevo < 0 THEN
                    -- bal_balon ya se actualizó (estado / almacén / cliente): un
                    -- error soft aquí confirmaría el cilindro movido sin su gas.
                    RAISE EXCEPTION 'Stock de gas insuficiente para registrar la salida';
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END;
    END IF;

    SELECT id_unidad_medida INTO v_id_unidad_medida FROM pro_producto WHERE id = p_id_producto;

    INSERT INTO inv_movimiento (
        fecha, id_tipo_movimiento, naturaleza, id_producto, id_balon, cantidad, id_unidad_medida,
        id_almacen_origen, id_almacen_destino, id_cliente,
        id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
        stock_anterior, stock_nuevo, id_estado_balon_snapshot,
        id_estado_balon_anterior, id_cliente_ubicacion_anterior, id_almacen_anterior,
        glosa, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'BALON', p_id_producto, p_id_balon, v_cantidad, v_id_unidad_medida,
        p_id_almacen_origen, p_id_almacen_destino, COALESCE(v_cliente_destino, p_id_cliente),
        p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
        v_stock_anterior, v_stock_nuevo, v_id_estado_balon,
        v_id_estado_anterior, v_id_cliente_anterior, v_id_almacen_anterior,
        p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
END;
$function$;


-- ===== database_sql/funciones/recargas-planta/bal_finalizar_recarga_planta.sql =====
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
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · el retorno exige la orden GENERADA / EMITIDA_SUNAT (en borrador no hay
--     salida que retornar);
--   · los envases se etiquetan SIEMPRE ORDEN_SALIDA + id orden: el retorno
--     físico es un hecho de la orden, no de la factura. Así anular la compra ya
--     no deshace la custodia de los cilindros;
--   · el gas lo registra bal_sincronizar_gas_retorno_planta (factura vinculada
--     o, sin factura, líneas de gas de la orden), la misma función que
--     re-sincroniza cuando la factura llega o cambia después.
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   · fecha_llegada_almacen / fecha_retorno solo se escriben cuando los
--     cilindros de verdad volvieron. Con p_guardar_balones_almacen = false y
--     sin ENTRADA_PLANTA_EXTERNA previa la llamada es metadata (factura, guía,
--     lote, ficha ICP) y NO declara el retorno. Antes bastaba con mandar la
--     fecha para que todo aguas abajo (listados, CompraForm, com_crear_compra)
--     diera el retorno por hecho: los cilindros quedaban EN_RECARGA_EXTERNA,
--     sin gas ingresado, y la compra ya no volvía a finalizarlo;
--   · el retorno ya no pisa doc_salida.id_almacen (el almacén de origen de la
--     salida se perdía): el almacén de llegada va a id_almacen_retorno;
--   · la fecha de P.H. del retorno baja al libro de P.H. de cada cilindro
--     (bal_sync_ph_desde_orden_salida);
--   · la ficha ICP (p_id_lote_protocolo) se aplica a los cilindros de la orden
--     aunque esta llamada no sea la que registra el retorno físico — antes solo
--     se aplicaba si el mismo llamado recorría el bucle de envases, así que por
--     el camino de Compras nunca llegaba a los balones.
-- Actualizada por database_sql/migraciones/20260911_w1_planta_retorno_traslado_gas.sql:
--   los cilindros de una orden de planta pueden volver por dos caminos — este
--   retorno y el recojo (bal_registrar_resultado_recojo) — y cada uno usa su
--   propio tipo de movimiento, así que el guard de doble retorno existente
--   (ENTRADA_PLANTA_EXTERNA) no veía al otro. Ahora el retorno se rechaza si hay
--   un recojo vivo (PROGRAMADO / EN_RUTA) sobre la orden o si el recojo ya
--   ingresó los cilindros (ENTRADA_LLENADO vigente).
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
    v_orden RECORD;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_retorno_fisico BOOLEAN;
    v_id_recojo_vivo INTEGER;
    v_retorno_por_recojo BOOLEAN;
    v_det RECORD;
    v_mov JSON;
    v_gas JSON;
    v_id_balones INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id, d.id_comprobante_compra, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_orden
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id_recarga_planta AND d.estado = 1
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
        RETURN json_build_object(
            'error', 'El documento no es una orden de recarga en planta externa',
            'registro', NULL
        );
    END IF;

    -- Sin salida generada no hay cilindros en planta que puedan volver: en
    -- borrador el inventario nunca se movió y el retorno dejaría envases
    -- "de vuelta" de un viaje que no existió.
    IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        RETURN json_build_object(
            'error', CASE
                WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden está anulada'
                ELSE 'La orden aún está en borrador: genérala antes de registrar el retorno'
            END,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_entrada_planta
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_entrada_planta IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado',
            'registro', NULL
        );
    END IF;

    -- Único criterio de "los cilindros volvieron": la entrada vigente de algún
    -- envase de la orden. Mismo criterio que bal_sincronizar_gas_retorno_planta
    -- y com_crear_compra, para que los tres coincidan siempre. Al anular la
    -- orden (inv_revertir_por_documento) los movimientos quedan con estado = 0
    -- y el retorno vuelve a estar pendiente.
    SELECT EXISTS (
        SELECT 1
        FROM inv_movimiento m
        JOIN doc_salida_detalle d ON d.id = m.id_documento_detalle
        WHERE m.estado = 1
          AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
          AND m.naturaleza = 'BALON'
          AND d.id_doc_salida = p_id_recarga_planta
          AND d.id_balon IS NOT NULL
          AND m.id_balon = d.id_balon
    ) INTO v_retorno_fisico;

    IF p_guardar_balones_almacen THEN
        -- Guard de doble retorno: va antes del UPDATE de cabecera para que un
        -- reenvío no deje la orden con fecha/almacén distintos a los de los
        -- movimientos ya hechos.
        IF v_retorno_fisico THEN
            RETURN json_build_object(
                'error', 'El retorno de esta orden ya fue registrado; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        -- El recojo es el otro camino por el que vuelven estos mismos
        -- cilindros. Con uno vivo, registrar el retorno acá los ingresaría al
        -- almacén y el cierre del recojo volvería a ingresarlos (con su gas)
        -- unos días después: el mismo viaje contado dos veces.
        SELECT r.id INTO v_id_recojo_vivo
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id_doc_salida = p_id_recarga_planta
          AND r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
        ORDER BY r.id
        LIMIT 1;

        IF v_id_recojo_vivo IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'La orden tiene el recojo #%s programado o en ruta; ciérralo o cancélalo antes de registrar el retorno',
                    v_id_recojo_vivo
                ),
                'registro', NULL
            );
        END IF;

        -- Recojo ya cerrado: los cilindros entraron con ENTRADA_LLENADO, que el
        -- guard de arriba (ENTRADA_PLANTA_EXTERNA) no ve. Sin esto, el retorno
        -- los ingresaba de nuevo con una segunda entrada de gas.
        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
            JOIN gen_lista_opciones td ON td.id = m.id_tipo_documento_origen
            JOIN doc_salida_detalle d
                ON d.id_doc_salida = p_id_recarga_planta
               AND d.estado = 1
               AND d.id_balon = m.id_balon
            WHERE m.estado = 1
              AND m.naturaleza = 'BALON'
              AND UPPER(TRIM(tm.nombre)) = 'ENTRADA_LLENADO'
              AND UPPER(TRIM(td.nombre)) = 'RECARGA'
              AND m.id_documento_origen = p_id_recarga_planta
        ) INTO v_retorno_por_recojo;

        IF v_retorno_por_recojo THEN
            RETURN json_build_object(
                'error', 'Los cilindros de esta orden ya volvieron por el recojo; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        IF p_id_almacen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'Indica el almacén al que llegan los cilindros',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Datos del retorno sobre el propio documento. Las fechas de llegada solo se
    -- escriben si los cilindros vuelven en esta llamada (p_guardar_balones_almacen)
    -- o si ya habían vuelto antes: sin entrada física, declarar la fecha dejaba
    -- la orden como retornada y bloqueaba el retorno de verdad.
    -- id_almacen queda como el origen de la salida; el almacén de llegada va a
    -- id_almacen_retorno.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen)
            ELSE fecha_llegada_almacen
        END,
        fecha_retorno = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_retorno)
            ELSE fecha_retorno
        END,
        id_almacen_retorno = CASE
            WHEN p_guardar_balones_almacen THEN COALESCE(p_id_almacen, id_almacen_retorno)
            ELSE id_almacen_retorno
        END,
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

        -- ------------------------------------------------------------
        -- 1) Envases: una línea por cilindro. Mueve SOLO el envase (custodia
        --    DISPONIBLE + LLENO en el almacén de llegada), igual que la línea
        --    del balón en la salida. Se etiqueta ORDEN_SALIDA + id orden
        --    (como la ida): el retorno físico no depende de la factura, así
        --    que anular la compra no lo deshace; anular la orden
        --    (doc_anular_salida) revierte ida y vuelta juntas.
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
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id_recarga_planta,
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

        v_retorno_fisico := TRUE;

        -- ------------------------------------------------------------
        -- 2) Gas: consolidado por producto con la cantidad que realmente
        --    ingresa (factura vinculada o, si no hay, líneas de gas de la
        --    orden). Es la misma función que vuelve a correr cuando la
        --    factura llega o cambia después del retorno.
        -- ------------------------------------------------------------
        v_gas := bal_sincronizar_gas_retorno_planta(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    -- Fase 5: los cilindros de la orden quedan con esta ficha como vigente,
    -- venga la llamada del retorno físico o de una edición posterior.
    IF p_id_lote_protocolo IS NOT NULL THEN
        SELECT array_agg(d.id_balon ORDER BY d.item)
        INTO v_id_balones
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL;

        IF array_length(v_id_balones, 1) IS NOT NULL THEN
            PERFORM bal_aplicar_lote_protocolo_balones(
                p_id_lote_protocolo,
                array_to_json(v_id_balones),
                p_id_usuario_auditoria
            );
        END IF;
    END IF;

    -- La P.H. del retorno es una prueba real hecha en planta: baja al libro de
    -- P.H. de cada cilindro que volvió. Sin retorno físico no hay qué anotar.
    IF v_retorno_fisico THEN
        PERFORM bal_sync_ph_desde_orden_salida(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta,
        'retorno_fisico', v_retorno_fisico,
        'gas', v_gas->'registro'
    ));
END;
$function$;

