-- ============================================================
-- Migración: inventario (errores soft tras mutar) y recojo de recarga en planta
-- Fecha: 2026-09-10
--
-- Regla que fija esta migración: una validación que falla DESPUÉS de haber
-- movido inventario no puede devolverse como json {'error': ...}; la función
-- retorna normalmente, la transacción se confirma y el cambio parcial queda
-- grabado. Ese caso es RAISE (rollback). Las validaciones previas a cualquier
-- mutación se mantienen como error soft.
--
-- P0
--  1) inv_registrar_movimiento (rama BALON): el gas insuficiente se detectaba
--     con bal_balon ya actualizado (estado / almacén / cliente) y se devolvía
--     soft, dejando el cilindro movido sin su gas. Ahora es RAISE.
--  2) inv_registrar_movimiento (rama PRODUCTO): el stock insuficiente se
--     comprueba antes de crear/reactivar la fila de pro_stock (error soft, sin
--     rastro); si aun así se llegara al saldo negativo con la fila ya tocada,
--     es RAISE.
--  3) inv_eliminar_movimiento: al revertir un traslado, el stock de destino se
--     valida ANTES de reintegrar el origen. Antes, un destino sin saldo
--     devolvía un error soft con el origen ya reintegrado (reversa a medias y
--     stock inventado).
--  4) doc_anular_salida: el id del estado ANULADA se resuelve antes de llamar a
--     inv_revertir_por_documento. Antes, si faltaba en el catálogo, la orden
--     quedaba con todo el inventario revertido y el ciclo aún activo.
--  5) bal_generar_recojo_recarga_planta estaba roto de tres formas: exigía el
--     ciclo 'ENVIADO' / 'CERRADO' (valores inexistentes en EstadoCicloSalida,
--     así que ninguna orden pasaba), pasaba p_id_doc_salida a bal_crear_recojo
--     (identificador que no es parámetro de la función) y recorría también las
--     líneas de producto, que reventaban la validación con un balón NULL.
--     Ahora exige GENERADA / EMITIDA_SUNAT, pasa p_id_recarga_planta y solo
--     recorre líneas con id_balon.
--  6) bal_crear_recojo: mismo check de ciclo corregido en la validación de
--     origen recarga en planta.
--
-- No toca la anulación de compras (fijada en
-- database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql).
-- doc_anular_salida se reemplaza completa sobre esa versión: el guard de compra
-- activa vinculada se conserva tal cual.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql
-- ============================================================


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_registrar_movimiento.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_registrar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- todo fallo posterior a una mutación de inventario es RAISE (rollback). El
-- stock insuficiente de gas se detectaba con bal_balon ya actualizado y se
-- devolvía soft, dejando el cilindro movido sin su gas.
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


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_eliminar_movimiento.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_eliminar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el stock de destino del traslado se valida antes de reintegrar el origen, así
-- ningún error soft deja la reversa a medias.
DROP FUNCTION IF EXISTS inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov inv_movimiento%ROWTYPE;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_stock_dest INTEGER;
    v_stock_dest_actual NUMERIC(12,4);
    v_stock_dest_revertido NUMERIC(12,4);
    v_id_estado_en_almacen INTEGER;
    v_id_almacen_stock INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_mov FROM inv_movimiento WHERE id = p_id AND estado = 1 FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_mov.id_documento_origen IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a un documento; anula el documento origen'
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
    v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
    IF v_es_traslado THEN
        v_es_salida := TRUE;
    ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
        v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
    ELSE
        v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
    END IF;

    IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
        -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
        -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
        IF v_mov.naturaleza = 'PRODUCTO' THEN
            v_id_almacen_stock := v_mov.id_almacen_origen;
        ELSE
            v_id_almacen_stock := COALESCE(
                CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino
            );
        END IF;

        SELECT id, stock INTO v_id_stock, v_stock_actual
        FROM pro_stock
        WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el registro de stock para revertir el movimiento');
        END IF;

        v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
        IF v_stock_revertido < 0 THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el movimiento porque revertiría un stock negativo');
        END IF;

        -- El destino del traslado se valida ANTES de tocar el origen: si se
        -- revisara después, un destino sin saldo devolvía un error soft con el
        -- origen ya reintegrado (traslado revertido a medias).
        IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
            SELECT id, stock INTO v_id_stock_dest, v_stock_dest_actual
            FROM pro_stock
            WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock_dest IS NULL THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el stock de destino para revertir el traslado');
            END IF;

            v_stock_dest_revertido := v_stock_dest_actual - v_mov.cantidad;
            IF v_stock_dest_revertido < 0 THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el traslado porque el destino ya no tiene esa cantidad');
            END IF;
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_id_stock_dest IS NOT NULL THEN
            UPDATE pro_stock
            SET stock = v_stock_dest_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock_dest;
        END IF;
    END IF;

    IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon
        SET
            id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
            id_cliente_ubicacion = CASE
                WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                ELSE NULL
            END,
            id_almacen = COALESCE(
                v_mov.id_almacen_anterior,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino,
                id_almacen
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_mov.id_balon AND estado = 1;
    END IF;

    UPDATE inv_movimiento
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_anular_salida.sql
-- ============================================================
-- Function: doc_anular_salida
--
-- Anula el ciclo de la OS y libera custodia logística (PENDIENTE_ENVIO /
-- EN_TRANSITO → DISPONIBLE). Si hay reparto vigente, hay que cancelarlo antes.
-- También se invoca en cascada desde ven_eliminar_comprobante (path con
-- id_venta): ese camino no pasa por inv_revertir_por_documento, así que la
-- liberación de balones vive aquí.
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
-- una orden de planta con compra activa vinculada no se anula (anular la
-- compra primero). Con ello la reversa por ORDEN_SALIDA cubre ida + retorno
-- completos (envases y gas declarado en la orden).
--
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el id del estado ANULADA se resuelve antes de revertir inventario.
DROP FUNCTION IF EXISTS doc_anular_salida(p_id integer, p_motivo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_anular_salida(p_id integer, p_motivo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_compra RECORD;
    v_id_anulada INTEGER;
    v_rev JSON;
    v_id_disponible INTEGER;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o ya fue eliminado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El documento fue aceptado por SUNAT; requiere comunicación de baja, no anulación directa',
            'registro', NULL
        );
    END IF;

    -- Orden de planta con factura vinculada: la compra tiene su gas del retorno
    -- etiquetado COMPRA, que la reversa por ORDEN_SALIDA no alcanza. Anular la
    -- compra primero (que desvincula y ajusta el gas) deja todo consistente.
    IF v_doc.id_comprobante_compra IS NOT NULL AND EXISTS (
        SELECT 1 FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra AND c.estado = 1
    ) THEN
        SELECT c.serie, c.numero INTO v_compra
        FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra;

        RETURN json_build_object(
            'error', format(
                'La orden tiene la compra %s vinculada; anúlala primero en Compras',
                COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), ''), '#' || v_doc.id_comprobante_compra)
            ),
            'registro', NULL
        );
    END IF;

    -- No anular si hay reparto / actividad operativa todavía vigente.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN (
              'CANCELADA', 'CANCELADO', 'REALIZADA'
          )
    ) THEN
        RETURN json_build_object(
            'error', 'Hay actividad de reparto vigente; cancélala antes de anular la OS',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_disponible
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_disponible IS NULL OR v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados DISPONIBLE, PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    -- El estado ANULADA se resuelve antes de revertir inventario: si faltara en
    -- el catálogo, el error soft se devolvía con los movimientos ya revertidos y
    -- la orden seguía activa.
    SELECT lo.id INTO v_id_anulada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'ANULADA' AND lo.estado = 1;

    IF v_id_anulada IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado ANULADA en catalogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    -- Solo se revierte lo que este documento movió por su cuenta.
    IF v_doc.id_venta IS NULL THEN
        v_rev := inv_revertir_por_documento('ORDEN_SALIDA', p_id, p_id_usuario_auditoria);

        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;

        UPDATE doc_salida_detalle
        SET id_movimiento = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_doc_salida = p_id;
    END IF;

    -- ------------------------------------------------------------
    -- Custodia logística: PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE
    --
    -- Con id_venta el inventario lo movió la venta (no hay movimiento OS),
    -- pero los cilindros sí quedaron comprometidos al crear la OS
    -- (doc_crear_desde_venta). Sin esto quedan atrapados al anular.
    -- Sin id_venta, cubre residuales que no hayan pasado por kardex BALON.
    -- ------------------------------------------------------------
    UPDATE bal_balon b
    SET id_estado_balon = v_id_disponible,
        id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE b.estado = 1
      AND b.id_estado_balon IN (v_id_pend_envio, v_id_transito)
      AND b.id IN (
          SELECT dd.id_balon
          FROM doc_salida_detalle dd
          WHERE dd.id_doc_salida = p_id
            AND dd.id_balon IS NOT NULL
            AND dd.estado = 1
          UNION
          SELECT vd.id_balon
          FROM ven_comprobante_detalle vd
          WHERE v_doc.id_venta IS NOT NULL
            AND vd.id_comprobante = v_doc.id_venta
            AND vd.id_balon IS NOT NULL
            AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
          UNION
          -- Misma cobertura que doc_crear_desde_venta / doc_obtener_salida
          SELECT pd.id_balon
          FROM bal_prestamo pr
          INNER JOIN bal_prestamo_detalle pd
              ON pd.id_prestamo = pr.id AND pd.estado = 1
          WHERE v_doc.id_venta IS NOT NULL
            AND pr.id_comprobante_venta = v_doc.id_venta
            AND pr.estado = 1
            AND pd.rol = 'ENTREGADO'
            AND pd.id_balon IS NOT NULL
      );

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_anulada,
        observaciones = TRIM(BOTH ' ' FROM CONCAT_WS(' | ',
            NULLIF(observaciones, ''),
            'Anulada: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'))),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/recojos/bal_crear_recojo.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el recojo de recarga en planta exige la orden GENERADA / EMITIDA_SUNAT; antes
-- pedía 'ENVIADO' / 'CERRADO', que no existen en EstadoCicloSalida.
DROP FUNCTION IF EXISTS bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer, p_id_alquiler integer, p_id_recarga_planta integer, p_fecha_programada date, p_hora_estimada time without time zone, p_id_usuario_responsable integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_marcar_balon_por_recoger boolean);

CREATE OR REPLACE FUNCTION bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_id_recarga_planta integer DEFAULT NULL::integer, p_fecha_programada date DEFAULT NULL::date, p_hora_estimada time without time zone DEFAULT NULL::time without time zone, p_id_usuario_responsable integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_marcar_balon_por_recoger boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_estado INTEGER;
    v_por_recoger INTEGER;
    x JSONB;
    v_pd INTEGER;
    v_ad INTEGER;
    v_b INTEGER;
    v_balon INTEGER;
    v_cliente INTEGER;
    v_dev DATE;
    v_len INTEGER;
    v_producto INTEGER;
    v_id_recarga_planta INTEGER;
    v_proveedor INTEGER;
    v_rp_estado VARCHAR;
    v_id_estado_balon_local INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_len := jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB));

    IF p_id_cliente IS NULL OR p_fecha_programada IS NULL THEN
        RETURN json_build_object(
            'error', 'Cliente y fecha son obligatorios',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'Cliente inválido', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
        WHERE p.id = p_id_prestamo
          AND p.id_cliente = p_id_cliente
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Préstamo activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
        WHERE a.id = p_id_alquiler
          AND a.id_cliente = p_id_cliente
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Alquiler activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    -- Validación de origen recarga en planta: el "cliente" del recojo es el proveedor
    IF p_id_recarga_planta IS NOT NULL THEN
        SELECT rp.id_proveedor, est.nombre
        INTO v_proveedor, v_rp_estado
        FROM doc_salida rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

        IF v_proveedor IS NULL THEN
            RETURN json_build_object(
                'error', 'Orden de recarga en planta no encontrada',
                'registro', NULL
            );
        END IF;

        -- Sin salida generada los cilindros nunca llegaron a la planta: no hay
        -- nada que recoger.
        IF COALESCE(v_rp_estado, '') NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_rp_estado = 'ANULADA' THEN 'La orden de recarga en planta está anulada'
                    ELSE 'La orden aún está en borrador: genérala antes de programar el recojo'
                END,
                'registro', NULL
            );
        END IF;

        IF v_proveedor <> p_id_cliente THEN
            RETURN json_build_object(
                'error', 'El cliente del recojo debe coincidir con el proveedor de la recarga',
                'registro', NULL
            );
        END IF;

        IF v_len = 0 THEN
            RETURN json_build_object(
                'error', 'El recojo de recarga en planta requiere al menos un cilindro',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Recojo sin cilindros: solo alquiler de regulador/accesorio
    IF v_len = 0 THEN
        IF p_id_alquiler IS NULL OR p_id_prestamo IS NOT NULL OR p_id_recarga_planta IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'Cliente, fecha y detalles son obligatorios',
                'registro', NULL
            );
        END IF;

        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock)
        INTO v_producto
        FROM bal_alquiler a
        WHERE a.id = p_id_alquiler AND a.estado = 1;

        IF v_producto IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene regulador/accesorio para recojo',
                'registro', NULL
            );
        END IF;

        -- Permitido con o sin cilindros pendientes: visita solo de regulador/accesorio

        IF EXISTS (
            SELECT 1
            FROM bal_recojo r
            JOIN gen_lista_opciones e ON e.id = r.id_estado
            WHERE r.id_alquiler = p_id_alquiler
              AND r.estado = 1
              AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
        ) THEN
            RETURN json_build_object(
                'error', 'El alquiler ya tiene un recojo programado o en ruta',
                'registro', NULL
            );
        END IF;
    END IF;

    SELECT lo.id INTO v_estado
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = 'PROGRAMADO' AND lo.estado = 1;

    SELECT lo.id INTO v_por_recoger
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'POR_RECOGER' AND lo.estado = 1;

    INSERT INTO bal_recojo (
        id_cliente,
        id_prestamo,
        id_alquiler,
        id_doc_salida,
        fecha_programada,
        hora_estimada,
        id_usuario_responsable,
        id_estado,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        p_id_alquiler,
        p_id_recarga_planta,
        p_fecha_programada,
        p_hora_estimada,
        p_id_usuario_responsable,
        v_estado,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR x IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles::JSONB, '[]'::JSONB))
    LOOP
        v_pd := COALESCE(
            NULLIF(x->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(x->>'id_prestamo_detalle', '')::INTEGER
        );
        v_ad := COALESCE(
            NULLIF(x->>'idAlquilerDetalle', '')::INTEGER,
            NULLIF(x->>'id_alquiler_detalle', '')::INTEGER
        );
        v_b := COALESCE(
            NULLIF(x->>'idBalon', '')::INTEGER,
            NULLIF(x->>'id_balon', '')::INTEGER
        );

        IF (v_pd IS NOT NULL)::INTEGER + (v_ad IS NOT NULL)::INTEGER + (v_b IS NOT NULL)::INTEGER <> 1 THEN
            RAISE EXCEPTION 'Cada detalle debe tener exactamente un origen (préstamo, alquiler o balón)';
        END IF;

        IF v_pd IS NOT NULL THEN
            SELECT pd.id_balon, p.id_cliente, pd.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_prestamo_detalle pd
            JOIN bal_prestamo p ON p.id = pd.id_prestamo
            JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
            WHERE pd.id = v_pd AND pd.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_prestamo IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_prestamo_detalle
                       WHERE id = v_pd AND id_prestamo = p_id_prestamo
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de préstamo inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_prestamo_detalle = v_pd
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de préstamo ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_prestamo_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_pd,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSIF v_ad IS NOT NULL THEN
            SELECT ad.id_balon, a.id_cliente, ad.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_alquiler_detalle ad
            JOIN bal_alquiler a ON a.id = ad.id_alquiler
            JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
            WHERE ad.id = v_ad AND ad.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_alquiler IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_alquiler_detalle
                       WHERE id = v_ad AND id_alquiler = p_id_alquiler
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de alquiler inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_alquiler_detalle = v_ad
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de alquiler ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_alquiler_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_ad,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSE
            -- Origen recarga en planta externa: el balón permanece EN_RECARGA_EXTERNA
            -- hasta que se cierra el recojo (distribución manual de gas).
            IF p_id_recarga_planta IS NULL THEN
                RAISE EXCEPTION 'El detalle por balón requiere el documento de salida de la recarga';
            END IF;

            SELECT b.id, b.id_estado_balon
            INTO v_balon, v_id_estado_balon_local
            FROM bal_balon b
            WHERE b.id = v_b AND b.estado = 1;

            IF v_balon IS NULL THEN
                RAISE EXCEPTION 'Balón % no encontrado', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM doc_salida_detalle d
                WHERE d.id_doc_salida = p_id_recarga_planta
                  AND d.id_balon = v_b
                  AND d.estado = 1
            ) THEN
                RAISE EXCEPTION 'El balón % no pertenece a la orden de recarga en planta', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM bal_balon b
                JOIN gen_lista_opciones e ON e.id = b.id_estado_balon
                WHERE b.id = v_b AND b.estado = 1 AND e.nombre = 'EN_RECARGA_EXTERNA'
            ) THEN
                RAISE EXCEPTION 'El balón % no está en estado EN_RECARGA_EXTERNA', v_b;
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_balon = v_b
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El balón % ya tiene un recojo programado', v_b;
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_balon,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_b,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END IF;
    END LOOP;

    RETURN bal_obtener_recojo(v_id);
EXCEPTION
    WHEN OTHERS THEN
        IF v_id IS NOT NULL THEN
            DELETE FROM bal_recojo WHERE id = v_id;
        END IF;
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


-- ============================================================
-- database_sql/funciones/recojos/bal_generar_recojo_recarga_planta.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_generar_recojo_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
--   · el recojo exige la orden GENERADA / EMITIDA_SUNAT (EstadoCicloSalida);
--     antes pedía 'ENVIADO' / 'CERRADO', que no existen en ese catálogo, así
--     que ninguna orden pasaba el filtro;
--   · la llamada a bal_crear_recojo usaba p_id_doc_salida, que no es parámetro
--     de esta función (error de compilación en tiempo de ejecución);
--   · el bucle ignora las líneas de producto (id_balon NULL), que reventaban la
--     validación de estado con un balón inexistente.
DROP FUNCTION IF EXISTS bal_generar_recojo_recarga_planta(p_id_recarga_planta integer, p_fecha_programada date, p_id_usuario_responsable integer, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_generar_recojo_recarga_planta(p_id_recarga_planta integer, p_fecha_programada date DEFAULT NULL::date, p_id_usuario_responsable integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_proveedor INTEGER;
    v_rp_estado VARCHAR;
    v_fecha DATE;
    v_detalles JSONB := '[]'::JSONB;
    v_item JSONB;
    v_id_balon INTEGER;
    v_id INTEGER;
    v_existente INTEGER;
    v_rec RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT rp.id_proveedor, est.nombre
    INTO v_proveedor, v_rp_estado
    FROM doc_salida rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
    WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

    IF v_proveedor IS NULL THEN
        RETURN json_build_object('error', 'Orden de recarga en planta no encontrada', 'registro', NULL);
    END IF;

    -- Sin salida generada los cilindros nunca llegaron a la planta: no hay nada
    -- que recoger.
    IF COALESCE(v_rp_estado, '') NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        RETURN json_build_object(
            'error', CASE
                WHEN v_rp_estado = 'ANULADA' THEN 'La orden de recarga en planta está anulada'
                ELSE 'La orden aún está en borrador: genérala antes de programar el recojo'
            END,
            'registro', NULL
        );
    END IF;

    SELECT r.id INTO v_existente
    FROM bal_recojo r
    WHERE r.id_doc_salida = p_id_recarga_planta
      AND r.estado = 1
    LIMIT 1;

    IF v_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'Ya existe un recojo para esta orden de recarga en planta',
            'registro', bal_obtener_recojo(v_existente)
        );
    END IF;

    v_fecha := COALESCE(p_fecha_programada, CURRENT_DATE + 5);

    -- Solo las líneas de cilindro: la orden también lleva líneas de gas y
    -- accesorios, que no se recogen.
    FOR v_rec IN
        SELECT d.id_balon
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL
    LOOP
        v_id_balon := v_rec.id_balon;
        IF NOT EXISTS (
            SELECT 1
            FROM bal_balon b
            JOIN gen_lista_opciones e ON e.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1 AND e.nombre = 'EN_RECARGA_EXTERNA'
        ) THEN
            RETURN json_build_object(
                'error', 'El balón ' || v_id_balon || ' no está en estado EN_RECARGA_EXTERNA',
                'registro', NULL
            );
        END IF;

        v_item := jsonb_build_object('id_balon', v_id_balon, 'observacion', NULL);
        v_detalles := v_detalles || jsonb_build_array(v_item);
    END LOOP;

    IF jsonb_array_length(v_detalles) = 0 THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta no tiene cilindros para recojo',
            'registro', NULL
        );
    END IF;

    RETURN bal_crear_recojo(
        v_proveedor,
        NULL,
        NULL,
        p_id_recarga_planta,
        v_fecha,
        NULL::TIME,
        p_id_usuario_responsable,
        NULLIF(TRIM(p_observacion), ''),
        v_detalles::JSON,
        p_id_usuario_auditoria
    );
END;
$function$;

