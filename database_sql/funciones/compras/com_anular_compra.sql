-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_anular_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
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
    v_id_estado_retornado INTEGER;
    v_id_estado_enviado   INTEGER;
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_doc_os      INTEGER;
    v_id_tipo_entrada_compra INTEGER;
    v_ids_balones_compra  INTEGER[];
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

    SELECT lo.id INTO v_id_tipo_doc_os
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ORDEN_SALIDA' AND lo.estado = 1
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
    -- Agrega por (producto, almacén) todos los ingresos a revertir: líneas
    -- afecta_stock, gas de cilindros comprados y ENTRADA_PLANTA (COMPRA u OS).
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
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND EXISTS (
                      SELECT 1 FROM gen_lista_opciones lo
                      WHERE lo.id = m.id_tipo_movimiento
                        AND UPPER(lo.nombre) = 'TRASLADO'
                  )
              )
              AND (
                  (v_id_tipo_doc_compra IS NOT NULL
                   AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
                   AND m.id_documento_origen = p_id_comprobante)
                  OR
                  (v_id_tipo_doc_os IS NOT NULL
                   AND m.id_tipo_documento_origen = v_id_tipo_doc_os
                   AND m.id_documento_origen IN (
                       SELECT ds.id FROM doc_salida ds
                       WHERE ds.id_comprobante_compra = p_id_comprobante AND ds.estado = 1
                   ))
              )
              -- Evitar doble conteo: líneas de detalle ya cubiertas arriba
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND v_id_tipo_doc_compra IS NOT NULL
                  AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
                  AND m.id_documento_origen = p_id_comprobante
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

    -- Desvincular órdenes de recarga planta que apuntaban a esta compra.
    SELECT lo.id INTO v_id_estado_retornado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'RETORNADO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_enviado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'ENVIADO' AND lo.estado = 1
    LIMIT 1;

    FOR v_orden IN
        SELECT id, fecha_llegada_almacen, id_almacen
        FROM doc_salida
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
    LOOP
        -- Revierte ORDEN_SALIDA (+ legado RECARGA) y deja cilindros en planta.
        PERFORM com_revertir_cilindros_recarga_compra(
            v_orden.id,
            p_id_comprobante,
            p_id_usuario_auditoria
        );

        UPDATE doc_salida
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_estado = CASE
                WHEN v_orden.fecha_llegada_almacen IS NOT NULL THEN COALESCE(v_id_estado_retornado, id_estado)
                ELSE COALESCE(v_id_estado_enviado, id_estado)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;
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
