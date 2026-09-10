-- ============================================================
-- Migración: planta externa — retorno en dos planos (envases + gas por compra)
-- Fecha: 2026-09-10
--
-- La orden RECARGA_PLANTA_EXTERNA (doc_salida) manda cilindros a recargar y su
-- detalle viene en dos planos, igual que lo registra doc_generar_salida:
--
--   · una línea por balón  → cantidad 1, mueve solo el envase
--   · una línea por gas    → cantidad total que sale, mueve pro_stock
--
-- El RETORNO (bal_finalizar_recarga_planta) no respetaba esa simetría: por
-- cada línea de balón registraba una ENTRADA_PLANTA_EXTERNA naturaleza BALON
-- con p_id_producto = gas del cilindro y p_cantidad = cantidad de la línea (1),
-- así que ingresaba 1 unidad de gas por cilindro y no existía ninguna entrada
-- consolidada por producto. El stock de gas quedaba mal después de cada
-- recarga.
--
-- 1) bal_finalizar_recarga_planta
--    a. Guard de doble retorno: si algún cilindro de la orden ya tiene una
--       ENTRADA_PLANTA_EXTERNA activa (estado = 1), devuelve error y no mueve
--       nada. Va antes del UPDATE de cabecera. Tras una anulación los
--       movimientos quedan con estado = 0, así que el retorno se puede volver
--       a registrar.
--    b. Envases: la línea del balón mueve SOLO el envase (naturaleza BALON,
--       p_id_producto NULL, cantidad 1, almacén destino = p_id_almacen), como
--       en la salida.
--    c. Gas, consolidado por producto con la cantidad que realmente ingresa:
--       · con compra vinculada (p_id_comprobante_compra o la que ya tenía la
--         orden): una entrada PRODUCTO por cada línea de gas (es_gas) de la
--         compra, cantidad convertida a la unidad del producto, etiquetada
--         COMPRA + id compra, id_documento_detalle = línea de compra;
--       · sin compra (o compra sin líneas de gas): fallback con las líneas de
--         gas del propio documento, etiquetadas ORDEN_SALIDA + id orden.
--       Naturaleza PRODUCTO: el almacén que recibe el stock es
--       p_id_almacen_origen (mismo criterio que el INGRESO de compra y que
--       inv_revertir_por_documento). 'creado' = false no es error (idempotente).
--    Compatibilidad con la anulación: com_anular_compra revierte por
--    ('COMPRA', id_compra) y com_revertir_cilindros_recarga_compra /
--    doc_anular_salida por ('ORDEN_SALIDA', id_doc). Envases y gas se
--    etiquetan con el mismo documento origen.
--
-- 2) com_crear_compra (solo el bloque IF p_id_doc_salida IS NOT NULL)
--    a. El retorno lo dispara SOLO el checkbox p_registrar_retorno_balones. La
--       fecha de llegada precargada desde la orden volvía a dispararlo.
--    b. Ya no exige lote/vencimiento/P.H. para el retorno: el protocolo se
--       registra por la ficha ICP desde el documento de salida. Si vienen, se
--       siguen copiando a la orden.
--    c. Si la orden ya tiene fecha_llegada_almacen (retorno registrado desde
--       el documento de salida) NO llama a bal_finalizar_recarga_planta aunque
--       el checkbox esté marcado: solo vincula la compra. Así la compra no
--       duplica el ingreso.
--    d. Corrige el nombre del argumento en la llamada a
--       bal_finalizar_recarga_planta (p_id_recarga_planta => p_id_doc_salida):
--       el rename a p_id_doc_salida fue solo en com_crear_compra y con el
--       nombre viejo la llamada no resolvía.
--
-- No cambia ninguna tabla ni ninguna firma de función.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql
-- ============================================================


-- ------------------------------------------------------------
-- bal_finalizar_recarga_planta
-- (copia de database_sql/funciones/recargas-planta/bal_finalizar_recarga_planta.sql)
-- ------------------------------------------------------------
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


-- ------------------------------------------------------------
-- com_crear_compra
-- (copia de database_sql/funciones/compras/com_crear_compra.sql)
-- ------------------------------------------------------------
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
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_recarga_planta integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);

CREATE OR REPLACE FUNCTION com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT false, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_registrar_retorno_balones boolean DEFAULT false, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_guia_retorno integer DEFAULT NULL::integer, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb)
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
    v_recarga_id_comprobante INTEGER;
    v_recarga_estado_nombre  VARCHAR;
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

    -- La orden debe existir, estar activa, y NO estar ya cerrada/facturada
    -- (id_comprobante_compra ya seteado por bal_finalizar_recarga_planta en
    -- una compra anterior) — si no, se estaría facturando la misma orden
    -- dos veces.
    IF p_id_doc_salida IS NOT NULL THEN
        SELECT rp.id_comprobante_compra, est.nombre
        INTO v_recarga_id_comprobante, v_recarga_estado_nombre
        FROM doc_salida rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_recarga_id_comprobante IS NOT NULL OR v_recarga_estado_nombre = 'CERRADO' THEN
            RETURN json_build_object(
                'error', 'La orden de recarga en planta externa indicada ya está cerrada/facturada y no se puede volver a vincular',
                'registro', NULL
            );
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

        -- Compra vinculada a orden de planta: el gas lo ingresa solo
        -- bal_finalizar_recarga_planta al marcar retorno. La línea es costo.
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
    -- El gas NO ingresa por líneas de compra: el retorno físico + INGRESO de gas
    -- lo hace solo bal_finalizar_recarga_planta.
    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM doc_salida WHERE id = p_id_doc_salida AND estado = 1
        ) THEN
            RAISE EXCEPTION 'Orden de recarga planta no encontrada o inactiva';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM doc_salida
            WHERE id = p_id_doc_salida
              AND estado = 1
              AND id_proveedor IS NOT NULL
              AND p_id_proveedor IS NOT NULL
              AND id_proveedor <> p_id_proveedor
        ) THEN
            RAISE EXCEPTION 'El proveedor de la compra no coincide con el de la orden de recarga';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM doc_salida
            WHERE id = p_id_doc_salida
              AND estado = 1
              AND id_comprobante_compra IS NOT NULL
              AND id_comprobante_compra <> v_id_compra
        ) THEN
            RAISE EXCEPTION 'La orden de recarga ya tiene otra compra vinculada';
        END IF;

        -- Retorno físico: SOLO el checkbox lo dispara. Antes bastaba con que
        -- viniera p_fecha_llegada_almacen, pero el formulario la precarga desde
        -- la orden cuando el retorno ya se registró en el documento de salida,
        -- y eso volvía a disparar el retorno (doble ingreso).
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        -- Lote/venc/P.H. ya no son obligatorios para el retorno: el protocolo se
        -- registra por la ficha ICP desde el documento de salida. Si vienen, se
        -- copian a la orden (COALESCE de abajo).
        SELECT
            COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(rp.lote), '')),
            COALESCE(p_fecha_vencimiento_lote, rp.fecha_vencimiento_lote),
            COALESCE(p_fecha_prueba_hidrostatica, rp.fecha_prueba_hidrostatica),
            rp.fecha_llegada_almacen IS NOT NULL
        INTO v_lote, v_fecha_venc_lote, v_fecha_ph, v_retorno_ya_registrado
        FROM doc_salida rp
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1;

        -- Si la orden ya tiene fecha_llegada_almacen, el retorno (envases + gas)
        -- ya lo registró bal_finalizar_recarga_planta desde el documento de
        -- salida: la compra solo se vincula y no vuelve a mover inventario.
        IF v_registrar_retorno AND NOT COALESCE(v_retorno_ya_registrado, FALSE) THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        -- bal_actualizar_recarga_planta desapareció en la unificación a doc_salida
        -- (Fase 2) y esta llamada quedó apuntando al vacío: vincular una compra a
        -- una orden de planta reventaba con "function does not exist". Ahora se
        -- escribe directo sobre doc_salida, que es donde vive la orden.
        --
        -- Serie/número de factura no se replican: quedan en la compra y las
        -- lecturas de la orden los resuelven por JOIN vía este FK.
        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen              = COALESCE(p_id_almacen, id_almacen),
            serie_guia_ingreso      = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        -- El retorno físico de los cilindros (custodia de los envases + entrada
        -- de gas consolidada con las cantidades de esta compra) lo hace
        -- bal_finalizar_recarga_planta. Aquí v_registrar_retorno ya quedó en
        -- FALSE si la orden tenía el retorno registrado, así la compra no
        -- duplica el ingreso.
        IF v_registrar_retorno THEN
            -- El parámetro de bal_finalizar_recarga_planta sigue llamándose
            -- p_id_recarga_planta; el rename a p_id_doc_salida fue solo en esta
            -- función. Con el nombre viejo la llamada no resolvía.
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
