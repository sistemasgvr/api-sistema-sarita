-- ============================================================
-- Migración: compras / retorno de planta — anulación, stock y validaciones (P0/P1)
-- Fecha: 2026-09-10
--
-- Modelo que fija esta migración: el RETORNO físico (envases) pertenece a la
-- orden de salida; la COMPRA solo aporta las cantidades de gas facturadas.
--
-- P0
--  1) com_anular_compra ya no revierte toda la orden por ('ORDEN_SALIDA', id)
--     (deshacía también la SALIDA_PLANTA_EXTERNA de ida). Revierte solo lo
--     etiquetado COMPRA, desvincula la orden y deja el gas del retorno según
--     las líneas de la orden (bal_sincronizar_gas_retorno_planta).
--     com_revertir_cilindros_recarga_compra se elimina.
--  2) Coherencia retorno/compra tras anular: el retorno se conserva (los
--     envases están etiquetados ORDEN_SALIDA), así que una nueva compra ve la
--     orden retornada, se vincula y re-sincroniza el gas a lo facturado.
--     Ya no hay estado a medias (fecha_llegada sin retorno o viceversa).
--  3) Se elimina la escritura a doc_salida.id_estado (columna inexistente;
--     el ciclo es id_estado_ciclo y no cambia al anular la factura).
--  4) com_actualizar/eliminar_compra_detalle y com_registrar_balones_compra:
--     todo fallo posterior a una mutación de inventario es RAISE (rollback);
--     las validaciones del lote de cilindros corren antes del bucle.
--  5) bal_finalizar_recarga_planta y com_crear_compra exigen la orden
--     GENERADA / EMITIDA_SUNAT (nada de retornos ni facturas sobre borradores).
--  6) Retorno antes de factura: al vincular la compra (o al crear/editar/
--     eliminar una línea de gas) el gas del retorno se re-sincroniza a las
--     cantidades facturadas.
--
-- P1
--  · Carrera: com_crear_compra bloquea la orden (FOR UPDATE) y se agrega el
--    índice único parcial uq_com_compra_doc_salida_activa.
--  · inv_revertir_por_documento: filtros opcionales por tipo de movimiento y
--    naturaleza (al final de la firma).
--  · doc_listar_salidas: p_id_proveedor, p_codigo_estado_ciclo (lista por
--    coma), total_cilindros / total_productos.
--  · doc_obtener_salida: id_unidad_capacidad_balon en el detalle.
--  · doc_anular_salida: no anula una orden con compra activa vinculada.
--
-- P2
--  · com_crear_compra: fuera el check muerto de 'CERRADO' y p_id_guia_retorno
--    (nunca se persistía). CAMBIA LA FIRMA: desplegar junto con la API.
--
-- Datos: los movimientos ENTRADA_PLANTA_EXTERNA de naturaleza BALON que
-- quedaron etiquetados COMPRA se re-etiquetan ORDEN_SALIDA + su orden, para
-- que anular la compra no los alcance y anular la orden sí.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql
-- ============================================================


-- ------------------------------------------------------------
-- Datos: envases del retorno etiquetados COMPRA -> ORDEN_SALIDA
-- ------------------------------------------------------------
DO $$
DECLARE
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_os INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_n INTEGER;
BEGIN
    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_os
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ORDEN_SALIDA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada_planta
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1 LIMIT 1;

    IF v_id_tipo_doc_compra IS NULL OR v_id_tipo_doc_os IS NULL OR v_id_tipo_entrada_planta IS NULL THEN
        RAISE NOTICE 'Re-etiquetado de envases omitido: faltan COMPRA / ORDEN_SALIDA / ENTRADA_PLANTA_EXTERNA en catálogos';
        RETURN;
    END IF;

    UPDATE inv_movimiento m
    SET id_tipo_documento_origen = v_id_tipo_doc_os,
        id_documento_origen = dd.id_doc_salida
    FROM doc_salida_detalle dd
    WHERE m.estado = 1
      AND m.naturaleza = 'BALON'
      AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
      AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
      AND dd.id = m.id_documento_detalle
      AND dd.id_balon = m.id_balon;

    GET DIAGNOSTICS v_n = ROW_COUNT;
    RAISE NOTICE 'Envases de retorno re-etiquetados COMPRA -> ORDEN_SALIDA: %', v_n;
END
$$;


-- ------------------------------------------------------------
-- Índice único parcial: una compra activa por orden de planta
-- ------------------------------------------------------------
DO $$
DECLARE
    v_dup RECORD;
BEGIN
    SELECT id_doc_salida, COUNT(*) AS n INTO v_dup
    FROM com_comprobante_compra
    WHERE estado = 1 AND id_doc_salida IS NOT NULL
    GROUP BY id_doc_salida
    HAVING COUNT(*) > 1
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'No se puede crear uq_com_compra_doc_salida_activa: la orden % tiene % compras activas vinculadas. Anule las sobrantes y vuelva a aplicar.', v_dup.id_doc_salida, v_dup.n;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = 'uq_com_compra_doc_salida_activa'
    ) THEN
        CREATE UNIQUE INDEX uq_com_compra_doc_salida_activa
            ON public.com_comprobante_compra USING btree (id_doc_salida)
            WHERE ((id_doc_salida IS NOT NULL) AND (estado = 1));
    END IF;
END
$$;


-- ------------------------------------------------------------
-- com_revertir_cilindros_recarga_compra: eliminada (su único caller era
-- com_anular_compra y su lógica ya no aplica).
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer);


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_revertir_por_documento.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_revertir_por_documento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
-- p_codigo_tipo_movimiento / p_naturaleza (2026-09-10): filtros opcionales
-- para revertir solo una parte de lo que movió un documento. Los necesita la
-- anulación de compras: la orden de planta tiene SALIDA_PLANTA_EXTERNA (ida) y
-- ENTRADA_PLANTA_EXTERNA (retorno) bajo el mismo origen ORDEN_SALIDA, y
-- revertir "todo el documento" deshacía también la ida. Van al final de la
-- firma para no romper las llamadas posicionales existentes.
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer);
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer, p_codigo_tipo_movimiento character varying, p_naturaleza character varying);

CREATE OR REPLACE FUNCTION inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_documento_detalle integer DEFAULT NULL::integer, p_codigo_tipo_movimiento character varying DEFAULT NULL::character varying, p_naturaleza character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_tipo_mov INTEGER;
    v_naturaleza VARCHAR;
    v_id_estado_en_almacen INTEGER;
    v_mov RECORD;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_almacen_stock INTEGER;
    v_count INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen IS NULL THEN
        RETURN json_build_object('revertidos', 0, 'error', 'id_documento_origen es obligatorio');
    END IF;

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object(
            'revertidos', 0,
            'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, ''))))
        );
    END IF;

    -- Filtro opcional por tipo de movimiento (TipoMovInvUnificado).
    IF NULLIF(TRIM(COALESCE(p_codigo_tipo_movimiento, '')), '') IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_mov
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_mov IS NULL THEN
            RETURN json_build_object(
                'revertidos', 0,
                'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento)))
            );
        END IF;
    END IF;

    v_naturaleza := NULLIF(UPPER(TRIM(COALESCE(p_naturaleza, ''))), '');

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
          AND (p_id_documento_detalle IS NULL OR id_documento_detalle = p_id_documento_detalle)
          AND (v_id_tipo_mov IS NULL OR id_tipo_movimiento = v_id_tipo_mov)
          AND (v_naturaleza IS NULL OR naturaleza = v_naturaleza)
        ORDER BY id DESC
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
            v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
        ELSE
            v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
        END IF;

        -- Revertir stock (producto, o gas cargado por un movimiento de balón).
        -- Misma estrictitud que inv_eliminar_movimiento: si no se puede revertir
        -- el stock, NO soft-deletear el movimiento (RAISE → rollback).
        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
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
                RAISE EXCEPTION
                    'No se encontró el registro de stock para revertir el movimiento %',
                    v_mov.id;
            END IF;

            v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
            IF v_stock_revertido < 0 THEN
                RAISE EXCEPTION
                    'No se puede revertir el movimiento % porque dejaría stock negativo',
                    v_mov.id;
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_actual
                FROM pro_stock
                WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    RAISE EXCEPTION
                        'No se encontró el stock de destino para revertir el traslado %',
                        v_mov.id;
                END IF;

                v_stock_revertido := v_stock_actual - v_mov.cantidad;
                IF v_stock_revertido < 0 THEN
                    RAISE EXCEPTION
                        'No se puede revertir el traslado % porque el destino ya no tiene esa cantidad',
                        v_mov.id;
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END IF;

        -- Restaurar custodia previa del balón (no forzar DISPONIBLE a ciegas).
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
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;


-- ============================================================
-- database_sql/funciones/recargas-planta/bal_sincronizar_gas_retorno_planta.sql
-- ============================================================
-- Function: bal_sincronizar_gas_retorno_planta
-- Creada: 2026-09-10 (migración 20260910_compras_anular_retorno_p0p1).
--
-- Deja el gas ingresado por el retorno de una orden RECARGA_PLANTA_EXTERNA
-- igual a lo que hoy se sabe que entró:
--
--   · con factura vinculada (doc_salida.id_comprobante_compra activa y con
--     líneas de gas): una ENTRADA_PLANTA_EXTERNA naturaleza PRODUCTO por cada
--     línea es_gas de la compra, etiquetada COMPRA + id compra,
--     id_documento_detalle = línea de compra;
--   · sin factura (o factura sin líneas de gas): una entrada por cada línea de
--     gas del propio documento, etiquetada ORDEN_SALIDA + id orden.
--
-- Antes de registrar revierte las entradas de gas vigentes del retorno (las de
-- la orden y las de la compra vinculada), así que es idempotente y sirve para
-- todos los momentos en que las cantidades cambian:
--   - bal_finalizar_recarga_planta: primer registro del retorno;
--   - com_crear_compra: la factura llega después del retorno (el gas pasa de
--     lo declarado en la orden a lo facturado);
--   - com_crear/actualizar/eliminar_compra_detalle: se corrige una línea de gas
--     de una compra ya vinculada;
--   - com_anular_compra: la factura se anula, el retorno se conserva y el gas
--     vuelve a lo declarado en la orden.
--
-- Solo actúa si el retorno físico está registrado: existe al menos una
-- ENTRADA_PLANTA_EXTERNA naturaleza BALON vigente para un cilindro de la orden.
-- Sin retorno no hay gas que ingresar (la factura sigue siendo solo costo).
--
-- Naturaleza PRODUCTO: el almacén que recibe el stock es p_id_almacen_origen
-- (mismo criterio que el INGRESO de compra y que inv_revertir_por_documento);
-- se usa el almacén de llegada guardado en la orden (doc_salida.id_almacen).
--
-- Falla con RAISE (no con {error}) porque siempre corre a mitad de otra
-- mutación: un error blando dejaría el inventario a medias sin rollback.
DROP FUNCTION IF EXISTS bal_sincronizar_gas_retorno_planta(p_id_doc_salida integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_sincronizar_gas_retorno_planta(p_id_doc_salida integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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

    SELECT d.id, d.id_almacen, d.id_proveedor, d.fecha_llegada_almacen,
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

    -- El retorno físico está registrado cuando algún cilindro de la orden tiene
    -- su entrada vigente. Solo la fecha (retorno "sin guardar en almacén") no
    -- mueve inventario y por tanto tampoco gas.
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

    -- ------------------------------------------------------------
    -- 1) Revertir el gas vigente del retorno (solo PRODUCTO + ENTRADA_PLANTA_
    --    EXTERNA: los envases y la ida no se tocan).
    -- ------------------------------------------------------------
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

    -- ------------------------------------------------------------
    -- 2a) Con factura: lo facturado por cada línea de gas, convertido a la
    --     unidad del producto.
    -- ------------------------------------------------------------
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

    -- ------------------------------------------------------------
    -- 2b) Sin factura (o factura sin líneas de gas): lo declarado en las líneas
    --     de gas de la propia orden (línea por producto, id_balon NULL).
    --     Distinto id_tipo_movimiento que la SALIDA de la misma línea, así que
    --     no choca con la idempotencia de la salida.
    -- ------------------------------------------------------------
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


-- ============================================================
-- database_sql/funciones/recargas-planta/bal_finalizar_recarga_planta.sql
-- ============================================================
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
    v_det RECORD;
    v_mov JSON;
    v_gas JSON;
    v_id_balones INTEGER[] := ARRAY[]::INTEGER[];
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

    -- Guard de doble retorno: si algún cilindro de esta orden ya tiene una
    -- ENTRADA_PLANTA_EXTERNA activa, el retorno ya se registró (desde el
    -- documento de salida o desde la compra) y no se vuelve a mover inventario.
    -- Va antes del UPDATE de cabecera para que un reenvío no deje la orden con
    -- fecha/almacén distintos a los de los movimientos ya hechos. Al anular la
    -- orden (inv_revertir_por_documento) los movimientos quedan con estado = 0.
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

        IF p_id_almacen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'Indica el almacén al que llegan los cilindros',
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

        -- ------------------------------------------------------------
        -- 2) Gas: consolidado por producto con la cantidad que realmente
        --    ingresa (factura vinculada o, si no hay, líneas de gas de la
        --    orden). Es la misma función que vuelve a correr cuando la
        --    factura llega o cambia después del retorno.
        -- ------------------------------------------------------------
        v_gas := bal_sincronizar_gas_retorno_planta(p_id_recarga_planta, p_id_usuario_auditoria);
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
        'id_recarga_planta', p_id_recarga_planta,
        'gas', v_gas->'registro'
    ));
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_crear_compra.sql
-- ============================================================
-- p_id_doc_salida: antes se llamaba p_id_recarga_planta. Desde la Fase 2 la
-- orden de recarga vive en doc_salida, así que el nombre viejo apuntaba a una
-- tabla que ya no existe. Misma posición en la firma: las llamadas posicionales
-- no cambian.
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql:
--   el retorno de cilindros desde Compras solo lo dispara el checkbox
--   (p_registrar_retorno_balones), ya no la fecha de llegada; no exige
--   lote/vencimiento/P.H. (el protocolo va por la ficha ICP del documento de
--   salida); y si la orden ya tiene fecha_llegada_almacen (retorno registrado
--   desde el documento de salida) solo vincula la compra, sin volver a mover
--   inventario.
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · la orden se bloquea (FOR UPDATE) al validarla: dos compras simultáneas
--     ya no pueden vincular la misma orden (además hay índice único parcial
--     sobre com_comprobante_compra.id_doc_salida);
--   · exige la orden GENERADA / EMITIDA_SUNAT (se quita el check muerto de
--     'CERRADO', que no existe en EstadoCicloSalida);
--   · si el retorno ya estaba registrado, al vincular la factura el gas se
--     re-sincroniza a las cantidades facturadas
--     (bal_sincronizar_gas_retorno_planta) y no se pisa el almacén de llegada;
--   · se elimina p_id_guia_retorno: nunca se persistía (la GRE del proveedor
--     va como serie/número de guía de ingreso, referencial).
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_recarga_planta integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);

CREATE OR REPLACE FUNCTION com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT false, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_registrar_retorno_balones boolean DEFAULT false, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_compra           INTEGER;
    v_link_planta         JSON;
    v_id_detalle          INTEGER;
    v_item                INTEGER := 0;
    v_linea               JSONB;
    v_id_producto         INTEGER;
    v_id_almacen_compra   INTEGER;
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_importe             NUMERIC(12,4);
    v_total_bruto         NUMERIC(12,4) := 0;
    v_tasa_igv            NUMERIC(6,4) := 0.18;
    v_base_imponible      NUMERIC(12,4);
    v_igv_calculado       NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
    v_ref_estado          INTEGER;
    v_ref_serie           VARCHAR;
    v_ref_numero          VARCHAR;
    v_glosa_final         VARCHAR;
    v_orden               RECORD;
    v_registrar_retorno   BOOLEAN;
    v_retorno_ya_registrado BOOLEAN := FALSE;
    v_fecha_llegada       DATE;
    v_lote                VARCHAR;
    v_fecha_venc_lote     DATE;
    v_fecha_ph            DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de la compra es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- El detalle de productos es opcional: se puede registrar la cabecera
    -- (por ejemplo, ligada a una orden de recarga en planta externa) y
    -- agregar las líneas después con com_crear_compra_detalle.
    IF p_detalles IS NOT NULL AND jsonb_typeof(p_detalles) IS DISTINCT FROM 'array' THEN
        RETURN json_build_object('error', 'El detalle de productos debe ser un arreglo JSON', 'registro', NULL);
    END IF;

    v_glosa_final := p_glosa;
    IF p_id_comprobante_referencia IS NOT NULL THEN
        SELECT estado, serie, numero INTO v_ref_estado, v_ref_serie, v_ref_numero
        FROM com_comprobante_compra
        WHERE id = p_id_comprobante_referencia;

        IF v_ref_estado IS NULL THEN
            RETURN json_build_object('error', 'La compra de referencia indicada no existe', 'registro', NULL);
        END IF;

        IF v_ref_estado <> 0 THEN
            RETURN json_build_object(
                'error', 'La compra de referencia debe estar anulada antes de registrar la corrección (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;

        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;

    -- La orden debe existir, estar activa, GENERADA (o con GRE emitida) y sin
    -- otra compra activa vinculada: si no, se estaría facturando la misma orden
    -- dos veces. FOR UPDATE: dos compras que lleguen a la vez por la misma
    -- orden se serializan aquí y la segunda ve el vínculo de la primera.
    IF p_id_doc_salida IS NOT NULL THEN
        SELECT
            rp.id,
            rp.id_proveedor,
            rp.id_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
            rp.fecha_prueba_hidrostatica,
            rp.fecha_llegada_almacen,
            c.id AS id_compra_vinculada,
            c.serie AS serie_compra_vinculada,
            c.numero AS numero_compra_vinculada,
            est.nombre AS estado_ciclo,
            tor.nombre AS tipo_orden
        INTO v_orden
        FROM doc_salida rp
        JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        JOIN gen_lista_opciones tor ON tor.id = rp.id_tipo_orden
        LEFT JOIN com_comprobante_compra c
            ON c.id = rp.id_comprobante_compra AND c.estado = 1
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1
        FOR UPDATE OF rp;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
            RETURN json_build_object('error', 'El documento indicado no es una orden de recarga en planta externa', 'registro', NULL);
        END IF;

        IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden de recarga indicada está anulada'
                    ELSE 'La orden de recarga aún está en borrador: genérala antes de registrar su factura'
                END,
                'registro', NULL
            );
        END IF;

        IF v_orden.id_compra_vinculada IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'La orden de recarga ya tiene la compra %s vinculada; anúlala antes de registrar otra',
                    COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_orden.serie_compra_vinculada, v_orden.numero_compra_vinculada)), ''), '#' || v_orden.id_compra_vinculada)
                ),
                'registro', NULL
            );
        END IF;

        IF v_orden.id_proveedor IS NOT NULL
           AND p_id_proveedor IS NOT NULL
           AND v_orden.id_proveedor <> p_id_proveedor
        THEN
            RETURN json_build_object('error', 'El proveedor de la compra no coincide con el de la orden de recarga', 'registro', NULL);
        END IF;
    END IF;

    -- IDs de listas resueltos una sola vez (no dentro del loop). Solo hace
    -- falta que estén configuradas si de verdad hay líneas que procesar.
    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_ref IS NULL THEN
            RAISE EXCEPTION 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef) en gen_lista_opciones';
        END IF;
    END IF;

    -- Cabecera (totales en 0; se recalculan al final con lo realmente insertado)
    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_compra;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles, '[]'::JSONB))
    LOOP
        v_item := v_item + 1;

        v_id_producto := (v_linea->>'id_producto')::INTEGER;
        v_cantidad := (v_linea->>'cantidad')::NUMERIC;
        v_precio_unitario := COALESCE((v_linea->>'precio_unitario')::NUMERIC, 0);
        v_id_almacen_linea := COALESCE((v_linea->>'id_almacen')::INTEGER, p_id_almacen);

        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;

        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;

        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;

        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;

        -- Payload puede forzar afecta_stock (p.ej. costo de recarga planta = false).
        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

        -- Compra vinculada a orden de planta: el gas lo ingresa solo el retorno
        -- (bal_finalizar_recarga_planta / bal_sincronizar_gas_retorno_planta).
        -- La línea es costo.
        IF p_id_doc_salida IS NOT NULL AND v_es_gas THEN
            v_afecta_stock := FALSE;
        END IF;

        v_importe := v_cantidad * v_precio_unitario;
        v_total_bruto := v_total_bruto + v_importe;

        v_descripcion_linea := v_linea->>'descripcion';
        IF v_descripcion_linea IS NULL THEN
            SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = v_id_producto;
        END IF;

        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
            id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
            afecta_stock, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_compra, v_item,
            (v_linea->>'id_clasificacion_gasto')::INTEGER,
            v_id_producto,
            v_descripcion_linea,
            (v_linea->>'id_unidad_medida')::INTEGER,
            v_id_almacen_linea,
            v_cantidad, v_precio_unitario, v_importe,
            v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_detalle;

        IF v_afecta_stock THEN
            v_result_movimiento := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => p_fecha,
                p_id_producto               => v_id_producto,
                p_id_balon                  => NULL,
                p_cantidad                  => v_cantidad,
                p_id_almacen_origen         => v_id_almacen_linea,
                p_id_almacen_destino        => NULL,
                p_id_cliente                => NULL,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen       => v_id_compra,
                p_id_documento_detalle      => v_id_detalle,
                p_glosa                     => 'Ingreso por compra ' || p_serie || '-' || p_numero,
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF (v_result_movimiento->>'error') IS NOT NULL THEN
                RAISE EXCEPTION '%', v_result_movimiento->>'error';
            END IF;
        END IF;

    END LOOP;

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_id_compra
              AND afecta_stock = TRUE
              AND estado = 1
        )
    WHERE id = v_id_compra;

    -- Vínculo opcional con orden de recarga planta externa (factura de costo).
    -- El gas NO ingresa por líneas de compra: lo ingresa el retorno con las
    -- cantidades de esta factura.
    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        -- Retorno físico: SOLO el checkbox lo dispara. Antes bastaba con que
        -- viniera p_fecha_llegada_almacen, pero el formulario la precarga desde
        -- la orden cuando el retorno ya se registró en el documento de salida,
        -- y eso volvía a disparar el retorno (doble ingreso).
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        -- Lote/venc/P.H. ya no son obligatorios para el retorno: el protocolo se
        -- registra por la ficha ICP desde el documento de salida. Si vienen, se
        -- copian a la orden (COALESCE de abajo).
        v_lote := COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(v_orden.lote), ''));
        v_fecha_venc_lote := COALESCE(p_fecha_vencimiento_lote, v_orden.fecha_vencimiento_lote);
        v_fecha_ph := COALESCE(p_fecha_prueba_hidrostatica, v_orden.fecha_prueba_hidrostatica);
        v_retorno_ya_registrado := v_orden.fecha_llegada_almacen IS NOT NULL;

        -- Si la orden ya tiene fecha_llegada_almacen, el retorno (envases + gas)
        -- ya lo registró bal_finalizar_recarga_planta desde el documento de
        -- salida: la compra se vincula y el gas se ajusta a lo facturado, sin
        -- volver a mover los cilindros.
        IF v_registrar_retorno AND NOT v_retorno_ya_registrado THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        -- Serie/número de factura no se replican: quedan en la compra y las
        -- lecturas de la orden los resuelven por JOIN vía este FK.
        -- El almacén de la orden solo se pisa cuando el retorno se registra
        -- ahora (es el almacén de llegada); con retorno previo se respeta el
        -- almacén donde realmente entraron los cilindros.
        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen              = CASE
                WHEN v_registrar_retorno THEN COALESCE(p_id_almacen, id_almacen)
                ELSE id_almacen
            END,
            serie_guia_ingreso      = COALESCE(NULLIF(TRIM(p_serie_guia_ingreso), ''), serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(NULLIF(TRIM(p_numero_guia_ingreso), ''), numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        IF v_registrar_retorno THEN
            -- El retorno físico de los cilindros (custodia de los envases +
            -- entrada de gas consolidada con las cantidades de esta compra) lo
            -- hace bal_finalizar_recarga_planta. Su parámetro sigue llamándose
            -- p_id_recarga_planta; el rename a p_id_doc_salida fue solo aquí.
            v_link_planta := bal_finalizar_recarga_planta(
                p_id_recarga_planta        => p_id_doc_salida,
                p_id_comprobante_compra    => v_id_compra,
                p_fecha_llegada_almacen    => v_fecha_llegada,
                p_id_almacen               => COALESCE(p_id_almacen, v_id_almacen_compra),
                p_id_proveedor             => p_id_proveedor,
                p_guardar_balones_almacen  => TRUE,
                p_lote                     => v_lote,
                p_fecha_vencimiento_lote   => v_fecha_venc_lote,
                p_fecha_prueba_hidrostatica => v_fecha_ph,
                p_id_usuario_auditoria     => p_id_usuario_auditoria
            );

            IF v_link_planta->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_link_planta->>'error';
            END IF;
        ELSIF v_retorno_ya_registrado THEN
            -- La factura llegó después del retorno: hasta ahora el stock tenía
            -- el gas declarado en la orden; pasa a tener lo facturado. Si el
            -- retorno se registró "sin guardar en almacén" no hay gas que
            -- ajustar y la función no hace nada.
            PERFORM bal_sincronizar_gas_retorno_planta(p_id_doc_salida, p_id_usuario_auditoria);
        END IF;
    END IF;

    -- Crédito / cuotas: genera CxP vinculada a la compra según condición de pago.
    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_crear_compra_detalle.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   si la compra está vinculada a una orden de planta con retorno registrado y
--   la línea es de gas, el gas ingresado se re-sincroniza a lo facturado
--   (bal_sincronizar_gas_retorno_planta).
DROP FUNCTION IF EXISTS com_crear_compra_detalle(p_id_comprobante integer, p_id_producto integer, p_cantidad numeric, p_precio_unitario numeric, p_id_clasificacion_gasto integer, p_descripcion character varying, p_id_unidad_medida integer, p_id_almacen integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_crear_compra_detalle(p_id_comprobante integer, p_id_producto integer, p_cantidad numeric, p_precio_unitario numeric DEFAULT 0, p_id_clasificacion_gasto integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_unidad_medida integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_detalle          INTEGER;
    v_item                INTEGER;
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_id_doc_salida       INTEGER;
    v_id_almacen_cabecera INTEGER;
    v_id_almacen_linea    INTEGER;
    v_fecha               DATE;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_importe             NUMERIC(12,4);
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT id_almacen, fecha, serie, numero, id_doc_salida
    INTO v_id_almacen_cabecera, v_fecha, v_serie, v_numero, v_id_doc_salida
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF v_id_almacen_cabecera IS NULL THEN
        RETURN json_build_object('error', 'La compra indicada no existe o está anulada', 'registro', NULL);
    END IF;

    SELECT afecta_stock, COALESCE(es_gas, FALSE)
    INTO v_afecta_stock, v_es_gas
    FROM pro_producto
    WHERE id = p_id_producto AND estado = 1;

    IF v_afecta_stock IS NULL THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Compra de costo de planta: el gas lo ingresa el retorno de la orden.
    IF v_id_doc_salida IS NOT NULL AND v_es_gas THEN
        v_afecta_stock := FALSE;
    END IF;

    v_id_almacen_linea := COALESCE(p_id_almacen, v_id_almacen_cabecera);

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(item), 0) + 1 INTO v_item
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante;

    v_importe := p_cantidad * p_precio_unitario;

    v_descripcion_linea := p_descripcion;
    IF v_descripcion_linea IS NULL THEN
        SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = p_id_producto;
    END IF;

    INSERT INTO com_comprobante_compra_detalle (
        id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
        id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
        afecta_stock, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_comprobante, v_item, p_id_clasificacion_gasto, p_id_producto, v_descripcion_linea,
        p_id_unidad_medida, v_id_almacen_linea, p_cantidad, p_precio_unitario, v_importe,
        v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_detalle;

    IF v_afecta_stock THEN
        v_result_movimiento := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'INGRESO',
            p_fecha                     => v_fecha,
            p_id_producto               => p_id_producto,
            p_cantidad                  => p_cantidad,
            p_id_almacen_origen         => v_id_almacen_linea,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen       => p_id_comprobante,
            p_id_documento_detalle      => v_id_detalle,
            p_glosa                     => 'Ingreso por compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    -- Línea de gas de una compra de planta: si el retorno ya ingresó gas, lo
    -- facturado cambió y el stock debe reflejarlo. Sin retorno no hace nada.
    IF v_id_doc_salida IS NOT NULL AND v_es_gas THEN
        PERFORM bal_sincronizar_gas_retorno_planta(v_id_doc_salida, p_id_usuario_auditoria);
    END IF;

    UPDATE com_comprobante_compra
    SET afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = p_id_comprobante
              AND afecta_stock = TRUE
              AND estado = 1
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_recalcular_totales_compra(p_id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_actualizar_compra_detalle.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_actualizar_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · los errores de inventario que ocurren después de revertir el INGRESO se
--     levantan con RAISE: antes se devolvían como {error} y la reversa quedaba
--     confirmada sin el nuevo movimiento (stock perdido);
--   · si la línea es de gas de una compra vinculada a una orden de planta con
--     retorno registrado, el gas ingresado se re-sincroniza a lo facturado.
DROP FUNCTION IF EXISTS com_actualizar_compra_detalle(p_id_detalle integer, p_cantidad numeric, p_precio_unitario numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_actualizar_compra_detalle(p_id_detalle integer, p_cantidad numeric DEFAULT NULL::numeric, p_precio_unitario numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_nueva_cantidad      NUMERIC(12,4);
    v_nuevo_precio        NUMERIC(12,6);
    v_delta               NUMERIC(12,4);
    v_importe             NUMERIC(12,4);
    v_result_movimiento   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.precio_unitario,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.fecha,
        c.serie,
        c.numero,
        c.id_doc_salida,
        COALESCE(p.es_gas, FALSE) AS es_gas
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    LEFT JOIN pro_producto p ON p.id = d.id_producto
    WHERE d.id = p_id_detalle
      AND d.estado = 1
      AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('error', 'La línea no existe o la compra está anulada', 'registro', NULL);
    END IF;

    v_nueva_cantidad := COALESCE(p_cantidad, v_detalle.cantidad);
    v_nuevo_precio := COALESCE(p_precio_unitario, v_detalle.precio_unitario);

    IF v_nueva_cantidad IS NULL OR v_nueva_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_nuevo_precio IS NULL OR v_nuevo_precio < 0 THEN
        RETURN json_build_object('error', 'El precio unitario no puede ser negativo', 'registro', NULL);
    END IF;

    -- Sin cambios relevantes
    IF v_nueva_cantidad = v_detalle.cantidad
       AND COALESCE(v_nuevo_precio, 0) = COALESCE(v_detalle.precio_unitario, 0)
    THEN
        RETURN com_obtener_compra(v_detalle.id_comprobante);
    END IF;

    v_delta := v_nueva_cantidad - v_detalle.cantidad;

    -- A partir de acá cualquier fallo se levanta con RAISE: la reversa del
    -- INGRESO y el nuevo movimiento tienen que confirmarse juntos o ninguno.
    IF v_detalle.afecta_stock AND v_delta <> 0 THEN
        v_result_movimiento := inv_revertir_por_documento(
            'COMPRA',
            v_detalle.id_comprobante,
            p_id_usuario_auditoria,
            v_detalle.id
        );
        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;

        v_result_movimiento := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'INGRESO',
            p_fecha                     => v_detalle.fecha,
            p_id_producto               => v_detalle.id_producto,
            p_cantidad                  => v_nueva_cantidad,
            p_id_almacen_origen         => v_detalle.id_almacen,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen       => v_detalle.id_comprobante,
            p_id_documento_detalle      => v_detalle.id,
            p_glosa                     => 'Ingreso por compra ' || v_detalle.serie || '-' || v_detalle.numero,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    v_importe := v_nueva_cantidad * v_nuevo_precio;

    UPDATE com_comprobante_compra_detalle
    SET cantidad = v_nueva_cantidad,
        precio_unitario = v_nuevo_precio,
        importe = v_importe,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    -- Gas de una compra de planta: la cantidad facturada es la que ingresó con
    -- el retorno; si cambió, el stock se ajusta. Va después del UPDATE porque
    -- la sincronización lee las líneas vigentes de la compra.
    IF v_detalle.id_doc_salida IS NOT NULL AND v_detalle.es_gas AND v_delta <> 0 THEN
        PERFORM bal_sincronizar_gas_retorno_planta(v_detalle.id_doc_salida, p_id_usuario_auditoria);
    END IF;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(v_detalle.id_comprobante);
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_eliminar_compra_detalle.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_eliminar_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · un error al revertir el INGRESO se levanta con RAISE (misma regla que el
--     resto de mutaciones de inventario: todo o nada);
--   · si la línea era de gas de una compra vinculada a una orden de planta con
--     retorno registrado, el gas ingresado se re-sincroniza sin esa línea.
DROP FUNCTION IF EXISTS com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_result_movimiento   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.serie,
        c.numero,
        c.id_doc_salida,
        COALESCE(p.es_gas, FALSE) AS es_gas
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    LEFT JOIN pro_producto p ON p.id = d.id_producto
    WHERE d.id = p_id_detalle AND d.estado = 1 AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_detalle);
    END IF;

    IF v_detalle.afecta_stock THEN
        v_result_movimiento := inv_revertir_por_documento(
            'COMPRA',
            v_detalle.id_comprobante,
            p_id_usuario_auditoria,
            v_detalle.id
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    -- Gas de una compra de planta: sin esta línea lo facturado cambia y el
    -- stock del retorno debe reflejarlo (o volver a lo declarado en la orden
    -- si era la última línea de gas).
    IF v_detalle.id_doc_salida IS NOT NULL AND v_detalle.es_gas THEN
        PERFORM bal_sincronizar_gas_retorno_planta(v_detalle.id_doc_salida, p_id_usuario_auditoria);
    END IF;

    UPDATE com_comprobante_compra
    SET afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_detalle.id_comprobante
              AND afecta_stock = TRUE
              AND estado = 1
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_detalle.id_comprobante;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_detalle);
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_registrar_balones_compra.sql
-- ============================================================
-- Function: com_registrar_balones_compra
-- Fase 7 — compra de cilindros: los da de alta en el libro y mueve inventario.
--
-- Comprar un balón no es como comprar un producto: el cilindro tiene identidad
-- propia, así que además de la línea de compra hay que crearlo en bal_balon y
-- registrar su ENTRADA_COMPRA en inv_movimiento. Un movimiento por cilindro,
-- no uno por línea (apunte 4.b.iv).
--
-- Si el cilindro viene cargado, `cantidad_gas` registra además la entrada del
-- gas como movimiento de PRODUCTO: comprar un balón lleno son dos hechos —
-- entra el envase y entra su contenido— y cada uno lleva su movimiento.
--
-- p_balones: [{ codigo_balon, numero_serie, id_tipo_balon, id_producto_gas,
--               id_marca_cilindro, fecha_fabricacion,
--               fecha_ultima_prueba_hidrostatica, cantidad_gas }]
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   las validaciones de códigos (vacío, repetido en el lote, ya en el libro)
--   corren sobre todo el lote antes del bucle, y dentro del bucle todo fallo
--   es RAISE. Antes un {error} blando en el 3.er cilindro dejaba los dos
--   primeros dados de alta con su movimiento (sin rollback).
DROP FUNCTION IF EXISTS com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb DEFAULT NULL::jsonb, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_compra            RECORD;
    v_linea             JSONB;
    v_codigo            VARCHAR;
    v_id_balon          INTEGER;
    v_id_propietario    INTEGER;
    v_id_estado         INTEGER;
    v_id_referencia     INTEGER;
    v_res               JSON;
    v_id_gas            INTEGER;
    v_cantidad_gas      NUMERIC(12,4);
    v_gas_total         NUMERIC(12,4) := 0;
    v_creados           INTEGER := 0;
    v_ids               INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_balones IS NULL OR jsonb_array_length(p_balones) = 0 THEN
        RETURN json_build_object('error', NULL, 'registro', json_build_object('creados', 0, 'id_balones', '[]'::JSON));
    END IF;

    SELECT c.id, c.fecha, c.serie, c.numero, c.id_almacen, c.id_proveedor,
           c.id_doc_salida,
           (
               c.id_doc_salida IS NULL
               OR EXISTS (
                   SELECT 1 FROM doc_salida d
                   WHERE d.id = c.id_doc_salida AND d.fecha_llegada_almacen IS NOT NULL
               )
           ) AS retorno_marcado
    INTO v_compra
    FROM com_comprobante_compra c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF v_compra.id IS NULL THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    -- Un cilindro comprado entra como propio y disponible en el almacén de la compra.
    SELECT lo.id INTO v_id_propietario
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'EMPRESA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1 LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Falta el estado DISPONIBLE en el catálogo EstadoBalon', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_referencia
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ReferenciaCilindro' AND lo.nombre = 'ALMACEN' AND lo.estado = 1 LIMIT 1;

    -- El gas entra al stock cuando los cilindros ya llegaron. Si la compra cuelga
    -- de una orden a planta cuyo retorno no se marcó, el gas todavía está en la
    -- planta y sumarlo inflaría el inventario. Se valida ANTES del bucle: si se
    -- comprobara por línea, los cilindros anteriores ya estarían dados de alta.
    IF NOT v_compra.retorno_marcado
       AND EXISTS (
           SELECT 1 FROM jsonb_array_elements(p_balones) AS a(x)
           WHERE COALESCE((x->>'cantidad_gas')::NUMERIC, 0) > 0
       )
    THEN
        RETURN json_build_object(
            'error', 'Los cilindros aún no figuran como retornados: marca el retorno en la orden de salida (o desde la compra) antes de ingresar el gas.',
            'registro', NULL
        );
    END IF;

    -- Validaciones de todo el lote ANTES de dar de alta el primero: dentro del
    -- bucle un {error} blando dejaría confirmados los cilindros anteriores
    -- (la función no falla, así que no hay rollback).
    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_balones) AS a(x)
        WHERE NULLIF(TRIM(x->>'codigo_balon'), '') IS NULL
    ) THEN
        RETURN json_build_object('error', 'Cada cilindro comprado necesita su código', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(x->>'codigo_balon')) INTO v_codigo
    FROM jsonb_array_elements(p_balones) AS a(x)
    GROUP BY UPPER(TRIM(x->>'codigo_balon'))
    HAVING COUNT(*) > 1
    LIMIT 1;

    IF v_codigo IS NOT NULL THEN
        RETURN json_build_object(
            'error', format('El código %s está repetido en el lote de cilindros', v_codigo),
            'registro', NULL
        );
    END IF;

    SELECT b.codigo_balon INTO v_codigo
    FROM bal_balon b
    WHERE b.estado = 1
      AND UPPER(TRIM(b.codigo_balon)) IN (
          SELECT UPPER(TRIM(x->>'codigo_balon')) FROM jsonb_array_elements(p_balones) AS a(x)
      )
    LIMIT 1;

    IF v_codigo IS NOT NULL THEN
        RETURN json_build_object(
            'error', format('El cilindro %s ya existe en el libro', v_codigo),
            'registro', NULL
        );
    END IF;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_balones)
    LOOP
        v_codigo := NULLIF(TRIM(v_linea->>'codigo_balon'), '');

        -- El gas no se elige a mano: lo define el tipo de balón. Un cilindro de
        -- oxígeno medicinal no puede entrar con otro gas por un descuido al tipear.
        v_id_gas := COALESCE(
            (v_linea->>'id_producto_gas')::INTEGER,
            (SELECT tb.id_gas FROM bal_tipo_balon tb WHERE tb.id = (v_linea->>'id_tipo_balon')::INTEGER)
        );
        v_cantidad_gas := COALESCE((v_linea->>'cantidad_gas')::NUMERIC, 0);

        v_res := bal_crear_balon(
            p_codigo_balon                     => v_codigo,
            p_fecha_registro                   => v_compra.fecha,
            p_id_almacen                       => v_compra.id_almacen,
            p_id_propietario                   => v_id_propietario,
            p_id_referencia                    => v_id_referencia,
            p_id_tipo_balon                    => (v_linea->>'id_tipo_balon')::INTEGER,
            p_id_producto_gas                  => v_id_gas,
            p_id_estado_balon                  => v_id_estado,
            p_fecha_ultima_prueba_hidrostatica => (v_linea->>'fecha_ultima_prueba_hidrostatica')::DATE,
            p_fecha_fabricacion                => (v_linea->>'fecha_fabricacion')::DATE,
            p_observacion                      => format(
                'Alta por compra %s',
                NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), '')
            ),
            p_numero_serie                     => NULLIF(TRIM(v_linea->>'numero_serie'), ''),
            p_id_marca_cilindro                => (v_linea->>'id_marca_cilindro')::INTEGER,
            p_id_usuario_auditoria             => p_id_usuario_auditoria
        );

        -- Desde el segundo cilindro ya hay altas confirmadas: cualquier fallo se
        -- levanta con RAISE para que la transacción entera se deshaga y no
        -- queden cilindros dados de alta a medias.
        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo dar de alta el cilindro %: %', v_codigo, v_res->>'error';
        END IF;

        v_id_balon := (v_res->'registro'->>'id')::INTEGER;

        IF v_id_balon IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el cilindro %', v_codigo;
        END IF;

        -- El cilindro ya existe en el libro: si el movimiento falla se levanta
        -- excepción para que no quede un balón dado de alta sin su entrada de
        -- inventario.
        -- id_documento_detalle = id_balon: cada cilindro es un hecho distinto para
        -- la idempotencia de inv_registrar_movimiento (sin esto, el 2.º gas del
        -- mismo producto reusa el 1.er movimiento y se pierde stock).
        v_res := inv_registrar_movimiento(
            p_naturaleza                   => 'BALON',
            p_codigo_tipo_movimiento       => 'ENTRADA_COMPRA',
            p_fecha                        => v_compra.fecha,
            p_id_balon                     => v_id_balon,
            p_cantidad                     => 1,
            p_id_almacen_destino           => v_compra.id_almacen,
            p_id_cliente                   => v_compra.id_proveedor,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen          => p_id_comprobante,
            p_id_documento_detalle         => v_id_balon,
            p_glosa                        => format('Ingreso del cilindro %s por compra', v_codigo),
            p_id_usuario_auditoria         => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo registrar la entrada del cilindro %: %',
                v_codigo, v_res->>'error';
        END IF;

        -- Gas del cilindro comprado: entra al stock del producto por la misma vía
        -- unificada que cualquier otro ingreso.
        IF v_cantidad_gas > 0 AND v_id_gas IS NOT NULL THEN
            v_res := inv_registrar_movimiento(
                p_naturaleza                   => 'PRODUCTO',
                p_codigo_tipo_movimiento       => 'INGRESO',
                p_fecha                        => v_compra.fecha,
                p_id_producto                  => v_id_gas,
                p_cantidad                     => v_cantidad_gas,
                p_id_almacen_origen            => v_compra.id_almacen,
                p_id_cliente                   => v_compra.id_proveedor,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen          => p_id_comprobante,
                p_id_documento_detalle         => v_id_balon,
                p_glosa                        => format('Gas del cilindro %s por compra', v_codigo),
                p_id_usuario_auditoria         => p_id_usuario_auditoria
            );

            IF (v_res->>'error') IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el gas del cilindro %: %',
                    v_codigo, v_res->>'error';
            END IF;

            v_gas_total := v_gas_total + v_cantidad_gas;
        END IF;

        v_ids := v_ids || v_id_balon;
        v_creados := v_creados + 1;
    END LOOP;

    UPDATE com_comprobante_compra
    SET afecta_inventario = TRUE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'creados', v_creados,
            'id_balones', array_to_json(v_ids),
            'gas_ingresado', v_gas_total
        )
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_anular_compra.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_anular_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   Anular la compra deshace SOLO lo que la compra movió (etiquetado COMPRA):
--   INGRESOs de líneas, cilindros comprados (ENTRADA_COMPRA + su gas) y el gas
--   del retorno de planta facturado (ENTRADA_PLANTA_EXTERNA PRODUCTO).
--   La orden de recarga vinculada se desvincula y conserva su retorno físico
--   (los envases están etiquetados ORDEN_SALIDA): el gas vuelve a lo declarado
--   en las líneas de la orden vía bal_sincronizar_gas_retorno_planta.
--   Antes revertía toda la orden por ('ORDEN_SALIDA', id) —incluida la
--   SALIDA_PLANTA_EXTERNA de ida— y escribía doc_salida.id_estado, columna
--   que no existe (el ciclo real es id_estado_ciclo y no cambia al anular la
--   factura). com_revertir_cilindros_recarga_compra queda eliminada.
DROP FUNCTION IF EXISTS com_anular_compra(p_id_comprobante integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_anular_compra(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_id_almacen_default  INTEGER;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
    v_faltantes           TEXT := '';
    v_nombre_producto     VARCHAR;
    v_nombre_almacen      VARCHAR;
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_entrada_compra INTEGER;
    v_ids_balones_compra  INTEGER[];
    v_balon_ocupado       RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_almacen, serie, numero
    INTO v_id_almacen_default, v_serie, v_numero
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante);
    END IF;

    -- No anular si la CxP vinculada ya tiene pagos.
    SELECT EXISTS (
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
              c.id_comprobante_compra = p_id_comprobante
              OR c.id_cuenta_padre IN (
                  SELECT fc.id
                  FROM fin_cuenta fc
                  WHERE fc.id_comprobante_compra = p_id_comprobante
                    AND fc.estado = 1
                    AND fc.id_cuenta_padre IS NULL
              )
          )
    ) INTO v_hay_pagos_cxp;

    IF v_hay_pagos_cxp THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id_comprobante,
            'error', 'No se puede anular: la cuenta por pagar vinculada tiene pagos registrados. Anule primero los pagos en Finanzas.'
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'ENTRADA_COMPRA' AND lo.estado = 1
    LIMIT 1;

    -- Cilindros dados de alta por esta compra (antes de revertir movimientos).
    SELECT COALESCE(array_agg(DISTINCT m.id_balon) FILTER (WHERE m.id_balon IS NOT NULL), ARRAY[]::INTEGER[])
    INTO v_ids_balones_compra
    FROM inv_movimiento m
    WHERE m.estado = 1
      AND m.naturaleza = 'BALON'
      AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
      AND m.id_documento_origen = p_id_comprobante
      AND (v_id_tipo_entrada_compra IS NULL OR m.id_tipo_movimiento = v_id_tipo_entrada_compra);

    -- ---------- PASO 1: VALIDACIÓN COMPLETA (sin modificar nada aún) ----------

    -- 1.a Un cilindro comprado que ya salió del almacén (prestado, vendido, en
    --     planta...) no se puede dar de baja como si nunca hubiera entrado.
    IF cardinality(v_ids_balones_compra) > 0 THEN
        SELECT b.codigo_balon, COALESCE(eb.nombre, 'sin estado') AS estado_balon
        INTO v_balon_ocupado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = ANY (v_ids_balones_compra)
          AND b.estado = 1
          AND COALESCE(eb.nombre, '') <> 'DISPONIBLE'
        LIMIT 1;

        IF FOUND THEN
            RETURN json_build_object(
                'eliminado', FALSE, 'id', p_id_comprobante,
                'error', format(
                    'No se puede anular: el cilindro %s comprado con esta factura ya no está disponible en almacén (estado %s).',
                    v_balon_ocupado.codigo_balon, v_balon_ocupado.estado_balon
                )
            );
        END IF;
    END IF;

    -- 1.b Stock suficiente para revertir todos los ingresos de producto que
    --     hizo esta compra, agregados por (producto, almacén): líneas
    --     afecta_stock, gas de cilindros comprados y gas del retorno de planta
    --     facturado. Todos están etiquetados COMPRA + esta compra.
    FOR v_detalle IN
        WITH ingresos AS (
            SELECT
                d.id_producto,
                COALESCE(d.id_almacen, v_id_almacen_default) AS id_almacen,
                d.cantidad
            FROM com_comprobante_compra_detalle d
            WHERE d.id_comprobante = p_id_comprobante
              AND d.afecta_stock = TRUE
              AND d.estado = 1

            UNION ALL

            SELECT
                m.id_producto,
                CASE
                    WHEN m.naturaleza = 'PRODUCTO' THEN m.id_almacen_origen
                    ELSE COALESCE(m.id_almacen_destino, m.id_almacen_origen)
                END AS id_almacen,
                m.cantidad
            FROM inv_movimiento m
            WHERE m.estado = 1
              AND m.id_producto IS NOT NULL
              AND m.stock_anterior IS NOT NULL
              AND m.stock_nuevo IS NOT NULL
              AND m.stock_nuevo >= m.stock_anterior
              AND v_id_tipo_doc_compra IS NOT NULL
              AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
              AND m.id_documento_origen = p_id_comprobante
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND EXISTS (
                      SELECT 1 FROM gen_lista_opciones lo
                      WHERE lo.id = m.id_tipo_movimiento
                        AND UPPER(lo.nombre) = 'TRASLADO'
                  )
              )
              -- Evitar doble conteo: líneas de detalle ya cubiertas arriba
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND m.id_documento_detalle IN (
                      SELECT d2.id FROM com_comprobante_compra_detalle d2
                      WHERE d2.id_comprobante = p_id_comprobante
                        AND d2.afecta_stock = TRUE
                        AND d2.estado = 1
                  )
              )
        )
        SELECT id_producto, id_almacen, SUM(cantidad) AS cantidad
        FROM ingresos
        WHERE id_producto IS NOT NULL AND id_almacen IS NOT NULL
        GROUP BY id_producto, id_almacen
    LOOP
        SELECT stock INTO v_stock_actual
        FROM pro_stock
        WHERE id_producto = v_detalle.id_producto
          AND id_almacen = v_detalle.id_almacen
          AND estado = 1
        FOR UPDATE;

        v_stock_actual := COALESCE(v_stock_actual, 0);

        IF v_stock_actual < v_detalle.cantidad THEN
            SELECT nombre INTO v_nombre_producto FROM pro_producto WHERE id = v_detalle.id_producto;
            SELECT nombre INTO v_nombre_almacen FROM gen_almacen WHERE id = v_detalle.id_almacen;

            v_faltantes := v_faltantes || format(
                E'\n- %s en %s: a revertir %s, disponible %s, falta %s',
                v_nombre_producto, v_nombre_almacen,
                v_detalle.cantidad, v_stock_actual, (v_detalle.cantidad - v_stock_actual)
            );
        END IF;
    END LOOP;

    IF v_faltantes <> '' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id_comprobante,
            'error', 'No se puede anular: el stock ya fue consumido por ventas u otros movimientos posteriores. Regularice el inventario antes de anular.' || v_faltantes
        );
    END IF;

    -- ---------- PASO 2: REVERSA REAL (ya validado que hay stock suficiente) ----------
    -- Todo lo etiquetado COMPRA + esta compra: INGRESOs de líneas, cilindros
    -- comprados con su gas y el gas del retorno de planta facturado. Los
    -- envases del retorno están etiquetados ORDEN_SALIDA y no se tocan.
    v_result_movimiento := inv_revertir_por_documento(
        'COMPRA',
        p_id_comprobante,
        p_id_usuario_auditoria
    );
    IF (v_result_movimiento->>'error') IS NOT NULL THEN
        RAISE EXCEPTION 'No se pudo anular: %', v_result_movimiento->>'error';
    END IF;

    UPDATE com_comprobante_compra
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id_comprobante;

    -- Baja lógica de cilindros creados por esta compra (ENTRADA_COMPRA).
    IF cardinality(v_ids_balones_compra) > 0 THEN
        UPDATE bal_balon
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = ANY (v_ids_balones_compra)
          AND estado = 1;
    END IF;

    -- Órdenes de recarga planta que apuntaban a esta compra: se desvinculan y
    -- conservan su ciclo (id_estado_ciclo) y su retorno físico. El gas del
    -- retorno, que era el facturado, vuelve a lo declarado en la orden; si la
    -- orden no tenía retorno registrado no hay nada que ajustar.
    FOR v_orden IN
        SELECT id
        FROM doc_salida
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
        FOR UPDATE
    LOOP
        UPDATE doc_salida
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;

        PERFORM bal_sincronizar_gas_retorno_planta(v_orden.id, p_id_usuario_auditoria);
    END LOOP;

    UPDATE bal_movimiento_recarga
    SET
        id_comprobante_compra = NULL,
        serie_factura = NULL,
        numero_factura = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_compra = p_id_comprobante
      AND estado = 1;

    -- Baja lógica de CxP vinculada (cabeceras + cuotas hijas). Ya validado sin pagos.
    FOR v_id_cuenta_padre IN
        SELECT fc.id
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
    LOOP
        UPDATE fin_cuenta
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cuenta_padre
           OR id_cuenta_padre = v_id_cuenta_padre;
    END LOOP;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_comprobante);
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
-- database_sql/funciones/documentos-salida/doc_listar_salidas.sql
-- ============================================================
-- Function: doc_listar_salidas
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · p_id_proveedor: filtra órdenes de planta por proveedor (el selector de
--     Compras solo debe ofrecer las del proveedor de la factura);
--   · p_codigo_estado_ciclo: uno o varios códigos de EstadoCicloSalida
--     separados por coma (p. ej. 'GENERADA,EMITIDA_SUNAT') para excluir
--     borradores/anuladas sin resolver ids en el cliente;
--   · total_cilindros / total_productos: total_items mezclaba líneas de balón
--     y de gas y se mostraba como "N cilindros".
--   Ambos parámetros van al final: las llamadas posicionales no cambian.

DROP FUNCTION IF EXISTS doc_listar_salidas(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_orden integer, p_id_estado_ciclo integer, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_emitido_sunat boolean, p_fecha_desde date, p_fecha_hasta date, p_codigo_tipo_orden character varying);
DROP FUNCTION IF EXISTS doc_listar_salidas(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_orden integer, p_id_estado_ciclo integer, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_emitido_sunat boolean, p_fecha_desde date, p_fecha_hasta date, p_codigo_tipo_orden character varying, p_sin_actividad_vigente boolean);

CREATE OR REPLACE FUNCTION doc_listar_salidas(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_id_tipo_orden integer DEFAULT NULL::integer,
    p_id_estado_ciclo integer DEFAULT NULL::integer,
    p_id_sucursal integer DEFAULT NULL::integer,
    p_id_almacen integer DEFAULT NULL::integer,
    p_id_cliente integer DEFAULT NULL::integer,
    p_emitido_sunat boolean DEFAULT NULL::boolean,
    p_fecha_desde date DEFAULT NULL::date,
    p_fecha_hasta date DEFAULT NULL::date,
    p_codigo_tipo_orden character varying DEFAULT NULL::character varying,
    p_sin_actividad_vigente boolean DEFAULT NULL::boolean,
    p_id_proveedor integer DEFAULT NULL::integer,
    p_codigo_estado_ciclo character varying DEFAULT NULL::character varying
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_estados_ciclo TEXT[];
BEGIN
    SET TIME ZONE 'America/Lima';

    -- 'GENERADA,EMITIDA_SUNAT' -> {GENERADA,EMITIDA_SUNAT}; vacío = sin filtro.
    IF NULLIF(TRIM(COALESCE(p_codigo_estado_ciclo, '')), '') IS NOT NULL THEN
        SELECT array_agg(UPPER(TRIM(x))) FILTER (WHERE TRIM(x) <> '')
        INTO v_estados_ciclo
        FROM unnest(string_to_array(p_codigo_estado_ciclo, ',')) AS x;
    END IF;

    SELECT COUNT(*),
           json_build_object(
               'total', COUNT(*),
               'borrador', COUNT(*) FILTER (WHERE ec.nombre = 'BORRADOR'),
               'generada', COUNT(*) FILTER (WHERE ec.nombre = 'GENERADA'),
               'emitida_sunat', COUNT(*) FILTER (WHERE ec.nombre = 'EMITIDA_SUNAT'),
               'anulada', COUNT(*) FILTER (WHERE ec.nombre = 'ANULADA')
           )
    INTO v_total, v_resumen
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
    WHERE d.estado = 1
      AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
      AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
      AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
      AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
      AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
      AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
      AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
      AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
      AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
      AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
      AND (
          p_sin_actividad_vigente IS NOT TRUE
          OR (
              ec.nombre NOT IN ('BORRADOR', 'ANULADA')
              AND NOT EXISTS (
                  SELECT 1
                  FROM age_actividad a
                  LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                  WHERE a.id_doc_salida = d.id
                    AND a.estado = 1
                    AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
              )
          )
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cli.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id, d.numero,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.fecha, d.fecha_traslado, d.fecha_llegada_almacen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            d.id_almacen_destino, almdest.nombre AS nombre_almacen_destino,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            d.id_comprobante_compra,
            d.lote, d.observaciones,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            CASE
                WHEN d.id_venta IS NOT NULL THEN (
                    SELECT COUNT(*) FROM ven_comprobante_detalle vd
                    WHERE vd.id_comprobante = d.id_venta AND (vd.estado = 1 OR vc.estado = 0)
                )
                ELSE (
                    SELECT COUNT(*) FROM doc_salida_detalle dd
                    WHERE dd.id_doc_salida = d.id AND dd.estado = 1
                )
            END AS total_items,
            -- Solo líneas propias: en órdenes desde venta el detalle vive en la venta.
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NOT NULL
            ) AS total_cilindros,
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NULL
            ) AS total_productos,
            d.fecha_creacion
        FROM doc_salida d
        JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        WHERE d.estado = 1
          AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
          AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
          AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
          AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
          AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
          AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
          AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
          AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
          AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
          AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
          AND (
              p_sin_actividad_vigente IS NOT TRUE
              OR (
                  ec.nombre NOT IN ('BORRADOR', 'ANULADA')
                  AND NOT EXISTS (
                      SELECT 1
                      FROM age_actividad a
                      LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                      WHERE a.id_doc_salida = d.id
                        AND a.estado = 1
                        AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
                  )
              )
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cli.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
          )
        ORDER BY d.fecha DESC, d.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total, 'resumen', v_resumen);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_obtener_salida.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_obtener_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
-- el detalle expone id_unidad_capacidad_balon (U.M. de la capacidad del tipo
-- de balón). Compras arma sus líneas de gas sumando capacidades, y sin el id
-- de esa unidad la línea quedaba con U.M. nula y el gas entraba sin convertir.
--
-- Actualizada por database_sql/migraciones/20260905_venta_gas_prestamo_garantia_join.sql:
-- con id_venta el detalle une los items de la venta con los cilindros
-- entregados en prestamo (rol ENTREGADO) y descarta las lineas de garantia.
DROP FUNCTION IF EXISTS doc_obtener_salida(p_id integer);

CREATE OR REPLACE FUNCTION doc_obtener_salida(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_id_venta INTEGER;
    v_venta_anulada BOOLEAN;
    v_detalle JSON;
    v_ultimo_item_venta INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id_venta INTO v_id_venta FROM doc_salida d WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_id_venta IS NOT NULL THEN
        SELECT (vc.estado = 0) INTO v_venta_anulada FROM ven_comprobante vc WHERE vc.id = v_id_venta;

        -- El detalle de una orden ligada a venta se arma por JOIN (principio
        -- "detalle no duplicado") y tiene dos orígenes:
        --   VENTA    — los ítems/productos del comprobante. Si la venta fue
        --              anulada sus líneas quedaron en estado=0
        --              (ven_eliminar_comprobante), así que el OR con
        --              v_venta_anulada evita que el documento se vea vacío en
        --              vez de mostrar qué se vendió originalmente. Cuando el
        --              ítem ya trae id_balon, esa fila representa el cilindro
        --              y el gas despachado.
        --   PRESTAMO — cilindros entregados en préstamo por esa misma venta
        --              que NO aparezcan ya en el detalle de la venta. Si el
        --              gas se vendió ligado al mismo cilindro, repetirlo aquí
        --              duplicaba el balón en la orden de salida.
        -- Se excluyen dos cosas: las líneas de garantía antiguas (garantía es
        -- dinero, no se despacha) y los cilindros de rol GARANTIA, que entran al
        -- almacén en vez de salir.
        -- El item de los cilindros continúa la numeración de la venta, así que
        -- se calcula antes: dentro del UNION no hay forma de mirar el otro lado.
        SELECT COALESCE(MAX(vd.item), 0) INTO v_ultimo_item_venta
        FROM ven_comprobante_detalle vd
        WHERE vd.id_comprobante = v_id_venta
          AND (vd.estado = 1 OR v_venta_anulada)
          AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a';

        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                vd.id,
                vd.item,
                vd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(vd.descripcion, p.nombre) AS descripcion,
                vd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                vd.cantidad,
                vd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                COALESCE(pgb.nombre, p.nombre) AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'VENTA'::VARCHAR AS origen_detalle
            FROM ven_comprobante_detalle vd
            LEFT JOIN pro_producto p ON p.id = vd.id_producto
            LEFT JOIN bal_balon b ON b.id = vd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = vd.id_unidad_medida
            WHERE vd.id_comprobante = v_id_venta
              AND (vd.estado = 1 OR v_venta_anulada)
              AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
            UNION ALL
            SELECT
                pd.id,
                v_ultimo_item_venta + (ROW_NUMBER() OVER (ORDER BY pd.id))::INTEGER AS item,
                NULL::INTEGER AS id_producto,
                b.codigo_balon AS codigo_producto,
                (
                    'Cilindro en préstamo — '
                    || COALESCE(b.codigo_balon, 'sin código')
                    || COALESCE(' (' || tb.nombre || ')', '')
                )::VARCHAR AS descripcion,
                pd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                1::NUMERIC AS cantidad,
                NULL::INTEGER AS id_unidad_medida,
                NULL::VARCHAR AS nombre_unidad_medida,
                NULL::VARCHAR AS codigo_unidad_medida,
                COALESCE(pgb.nombre, tb.nombre)::VARCHAR AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'PRESTAMO'::VARCHAR AS origen_detalle
            FROM bal_prestamo pr
            INNER JOIN bal_prestamo_detalle pd
                ON pd.id_prestamo = pr.id AND pd.estado = 1
            LEFT JOIN bal_balon b ON b.id = pd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            WHERE pr.id_comprobante_venta = v_id_venta
              AND pr.estado = 1
              AND pd.rol = 'ENTREGADO'
              AND pd.id_balon IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM ven_comprobante_detalle vd_bal
                  WHERE vd_bal.id_comprobante = v_id_venta
                    AND vd_bal.id_balon = pd.id_balon
                    AND (vd_bal.estado = 1 OR v_venta_anulada)
                    AND COALESCE(vd_bal.descripcion, '') !~* 'garant[ií]a'
              )
        ) t;
    ELSE
        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                dd.id,
                dd.item,
                dd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(dd.descripcion, p.nombre, b.codigo_balon) AS descripcion,
                dd.id_balon,
                b.codigo_balon,
                -- Tipo y almacén del cilindro: la card del detalle los muestra
                -- igual que el selector, y el detalle no los tenía.
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                -- Capacidad del tipo: en planta externa el editor la suma por
                -- gas para topar cuánto se puede declarar que sale. Sin esto,
                -- al recargar un documento ya guardado no habría con qué
                -- calcular ese tope.
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                -- Gas del cilindro: decide si la orden puede asociarse a una
                -- ficha de lote y protocolo (una ficha cubre un solo gas).
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                dd.cantidad,
                dd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                p.nombre AS nombre_producto,
                dd.glosa,
                dd.id_movimiento,
                'PROPIO'::VARCHAR AS origen_detalle
            FROM doc_salida_detalle dd
            LEFT JOIN pro_producto p ON p.id = dd.id_producto
            LEFT JOIN bal_balon b ON b.id = dd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = dd.id_unidad_medida
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
        ) t;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            d.id, d.numero,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.id_doc_salida_origen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            -- Destino del traslado: además de mover el stock, es la dirección
            -- de llegada por defecto de la guía de remisión.
            d.id_almacen_destino,
            almdest.nombre AS nombre_almacen_destino,
            almdest.ubicacion AS direccion_almacen_destino,
            almdest.id_distrito AS id_distrito_almacen_destino,
            almdest.id_provincia AS id_provincia_almacen_destino,
            almdest.id_departamento AS id_departamento_almacen_destino,
            depalmdest.id_pais AS id_pais_almacen_destino,
            -- Ubicación del almacén: es el punto de partida por defecto de la
            -- guía de remisión, para no volver a tipear el origen.
            alm.ubicacion AS direccion_almacen,
            alm.id_distrito AS id_distrito_almacen,
            alm.id_provincia AS id_provincia_almacen,
            alm.id_departamento AS id_departamento_almacen,
            distalm.codigo_ubigeo AS ubigeo_almacen,
            depalm.id_pais AS id_pais_almacen,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_destinatario, d.destinatario_nombre, d.destinatario_documento,
            COALESCE(NULLIF(TRIM(d.destinatario_nombre), ''),
                     NULLIF(TRIM(dest.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno)), '')) AS nombre_destinatario,
            COALESCE(NULLIF(TRIM(d.destinatario_documento), ''), dest.numero_documento) AS documento_destinatario,
            tddest.nombre AS nombre_tipo_doc_destinatario,
            COALESCE(NULLIF(TRIM(d.remitente_documento), ''), cli.numero_documento) AS documento_cliente,
            tdcli.nombre AS nombre_tipo_doc_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            prov.numero_documento AS documento_proveedor,
            d.fecha, d.fecha_traslado, d.fecha_retorno,
            d.id_tipo_guia_remision, tgr.nombre AS nombre_tipo_guia_remision,
            tgr.descripcion AS codigo_tipo_guia,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            d.ticket_sunat, d.hash_documento, d.cdr_respuesta,
            d.tipo_cambio,
            d.id_motivo_traslado, mt.nombre AS nombre_motivo_traslado,
            mt.descripcion AS codigo_motivo_traslado,
            d.id_modalidad_traslado, mod.nombre AS nombre_modalidad_traslado,
            mod.descripcion AS codigo_modalidad_traslado,
            d.id_unidad_medida, umd.nombre AS nombre_unidad_medida,
            umd.descripcion AS codigo_unidad_medida,
            d.peso_bruto, d.numero_bultos,
            d.direccion_origen, d.id_distrito_origen,
            disto.codigo_ubigeo AS ubigeo_origen,
            disto.id_provincia AS id_provincia_origen,
            provo.id_departamento AS id_departamento_origen,
            depo.id_pais AS id_pais_origen,
            d.direccion_llegada, d.id_distrito_llegada,
            distl.codigo_ubigeo AS ubigeo_llegada,
            distl.id_provincia AS id_provincia_llegada,
            provl.id_departamento AS id_departamento_llegada,
            depl.id_pais AS id_pais_llegada,
            d.direccion_entrega, d.referencia_entrega, d.latitud, d.longitud,
            d.id_distrito_entrega, distent.nombre AS nombre_distrito_entrega,
            distent.codigo_ubigeo AS ubigeo_entrega,
            distent.id_provincia AS id_provincia_entrega,
            propent.id_departamento AS id_departamento_entrega,
            depent.id_pais AS id_pais_entrega,
            d.id_direccion_cliente,
            d.id_transportista,
            COALESCE(NULLIF(TRIM(trans.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', trans.nombres, trans.apellido_paterno, trans.apellido_materno)), '')) AS nombre_transportista,
            trans.numero_documento AS documento_transportista,
            d.id_chofer,
            TRIM(CONCAT_WS(' ', cho.nombres, cho.apellido_paterno, cho.apellido_materno)) AS nombre_chofer,
            cho.numero_documento AS documento_chofer,
            tdch.descripcion AS codigo_tipo_doc_chofer,
            (SELECT lic.codigo FROM gen_licencia lic
              WHERE lic.id_chofer = cho.id AND lic.estado = 1
              ORDER BY lic.fecha_vencimiento DESC LIMIT 1) AS licencia_chofer,
            d.id_vehiculo, veh.placa AS placa_vehiculo, veh.placa,
            d.id_responsable, d.remitente_nombre, d.remitente_documento,
            d.id_comprobante_compra,
            d.serie_guia_salida, d.numero_guia_salida,
            d.serie_guia_ingreso, d.numero_guia_ingreso,
            d.serie_factura, d.numero_factura,
            d.fecha_llegada_almacen, d.lote, d.fecha_vencimiento_lote, d.fecha_prueba_hidrostatica,
            d.periodo_contable, d.operacion, d.observaciones, d.id_archivo_pdf,
            d.estado, d.fecha_creacion, d.fecha_modificacion,
            d.id_usuario_creacion, uc.nombre AS nombre_usuario_creacion,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            COALESCE(v_venta_anulada, FALSE) AS venta_anulada,
            v_detalle AS detalle,
            (
                SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON)
                FROM (
                    SELECT dr.id, dr.id_tipo_comprobante, tc.nombre AS nombre_tipo_comprobante,
                           tc.descripcion AS codigo_tipo_comprobante,
                           dr.id_comprobante, dr.serie, dr.numero, dr.fecha
                    FROM doc_salida_referencia dr
                    LEFT JOIN gen_lista_opciones tc ON tc.id = dr.id_tipo_comprobante
                    WHERE dr.id_doc_salida = d.id AND dr.estado = 1
                ) r
            ) AS referencias
        FROM doc_salida d
        LEFT JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        LEFT JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN gen_lista_opciones tgr ON tgr.id = d.id_tipo_guia_remision
        LEFT JOIN gen_lista_opciones mt ON mt.id = d.id_motivo_traslado
        LEFT JOIN gen_lista_opciones mod ON mod.id = d.id_modalidad_traslado
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        LEFT JOIN gen_vehiculo veh ON veh.id = d.id_vehiculo
        LEFT JOIN gen_lista_opciones umd ON umd.id = d.id_unidad_medida
        LEFT JOIN gen_distrito distalm ON distalm.id = alm.id_distrito
        LEFT JOIN gen_departamento depalm ON depalm.id = alm.id_departamento
        LEFT JOIN gen_departamento depalmdest ON depalmdest.id = almdest.id_departamento
        LEFT JOIN gen_distrito disto ON disto.id = d.id_distrito_origen
        LEFT JOIN gen_provincia provo ON provo.id = disto.id_provincia
        LEFT JOIN gen_departamento depo ON depo.id = provo.id_departamento
        LEFT JOIN gen_distrito distl ON distl.id = d.id_distrito_llegada
        LEFT JOIN gen_provincia provl ON provl.id = distl.id_provincia
        LEFT JOIN gen_departamento depl ON depl.id = provl.id_departamento
        LEFT JOIN gen_distrito distent ON distent.id = d.id_distrito_entrega
        LEFT JOIN gen_provincia propent ON propent.id = distent.id_provincia
        LEFT JOIN gen_departamento depent ON depent.id = propent.id_departamento
        LEFT JOIN cli_clientes trans ON trans.id = d.id_transportista
        LEFT JOIN cli_clientes dest ON dest.id = d.id_destinatario
        LEFT JOIN gen_chofer cho ON cho.id = d.id_chofer
        LEFT JOIN gen_lista_opciones tdch ON tdch.id = cho.id_tipo_documento
        LEFT JOIN gen_lista_opciones tddest ON tddest.id = dest.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdcli ON tdcli.id = cli.id_tipo_documento
        LEFT JOIN auth_usuarios uc ON uc.id = d.id_usuario_creacion
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
