-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_eliminar_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
--
-- Fase 2 — al anular la venta, cascada a su orden de salida vigente
-- (doc_salida.id_venta): el detalle de un doc_salida ORDEN_SALIDA_VENTA se
-- toma por JOIN de ven_comprobante_detalle (principio "detalle no
-- duplicado"), que este mismo procedimiento deja en estado=0 más abajo — sin
-- esta cascada, el documento quedaba "activo" pero sin ítems, indistinguible
-- de un bug. doc_anular_salida ya es seguro de llamar aquí: para documentos
-- con id_venta NO revierte inventario (lo movió la venta, no el documento),
-- pero SÍ libera custodia PENDIENTE_ENVIO/EN_TRANSITO → DISPONIBLE y bloquea
-- si hay reparto vigente. Ver también doc_obtener_salida.sql
-- (ahora sigue mostrando el detalle de una venta anulada, en vez de vaciarlo).
--
-- Actualizada por database_sql/migraciones/20260910_venta_custodia_mostrador_anular.sql:
--   · Bloqueo duro si el reparto de la venta ya está REALIZADA — la mercadería
--     está en poder del cliente y reponer stock sería inventar envases.
--   · La liberación residual de cilindros cubre también EN_PODER_CLIENTE, que
--     es donde los deja una venta de mostrador sin orden de salida
--     (ven_confirmar_entrega_mostrador). Sin reparto realizado —lo único que
--     puede dejarlos así— el cilindro vuelve al almacén de la venta.
--
-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js
-- cuando el usuario lo confirme.
DROP FUNCTION IF EXISTS ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
    v_anul JSON;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_os_id INTEGER;
    v_id_almacen_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, c.serie, c.numero, c.id_almacen
    INTO v_estado_sunat, v_serie, v_numero, v_id_almacen_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
        );
    END IF;

    -- Reparto entregado: doc_anular_salida también lo bloquea, pero el mensaje
    -- se resuelve aquí para que la venta explique el motivo en sus términos.
    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN age_actividad a ON a.id_doc_salida = d.id AND a.estado = 1
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error',
            'La entrega de esta venta ya fue realizada y los cilindros están en poder del cliente; '
            || 'no se puede anular. Emite una nota de crédito y registra la devolución.'
        );
    END IF;

    -- Cascada OS ANTES del soft-delete: doc_anular_salida localiza balones
    -- por ven_comprobante_detalle (aún estado=1), libera PENDIENTE_ENVIO /
    -- EN_TRANSITO → DISPONIBLE, y falla con error si hay reparto vigente.
    -- PERFORM descartaba ese error; aquí se propaga.
    FOR v_os_id IN
        SELECT d.id
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND ec.nombre <> 'ANULADA'
    LOOP
        v_anul := doc_anular_salida(
            v_os_id,
            format('Venta %s-%s anulada', COALESCE(v_serie, ''), COALESCE(v_numero, p_id::text)),
            p_id_usuario_auditoria
        );
        IF v_anul->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', v_anul->>'error'
            );
        END IF;
    END LOOP;

    -- Reserva de venta sin OS: ven_crear_comprobante dejó PENDIENTE_ENVIO en
    -- cilindros DISPONIBLE vendidos. Si no hubo OS (o quedó residual), liberar.
    -- Con OS vigente doc_anular_salida ya lo hizo; este UPDATE es no-op.
    --
    -- EN_PODER_CLIENTE también entra: es donde deja los cilindros la venta de
    -- mostrador sin orden de salida. El único otro camino a ese estado es el
    -- reparto culminado, y ese ya abortó la anulación más arriba.
    UPDATE bal_balon b
    SET id_estado_balon = lo_disp.id,
        id_almacen = COALESCE(b.id_almacen, v_id_almacen_venta),
        id_cliente_ubicacion = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    CROSS JOIN LATERAL (
        SELECT lo.id
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1
    ) lo_disp
    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE d.id_comprobante = p_id
      AND d.estado = 1
      AND d.id_balon = b.id
      AND b.estado = 1
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
      AND lo_disp.id IS NOT NULL
      AND UPPER(TRIM(eb.nombre)) IN ('PENDIENTE_ENVIO', 'EN_PODER_CLIENTE');

    -- Revertir stock, CxC impaga y custodia (préstamo/recarga/alquiler/GRE)
    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante')
        );
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    -- Fase 3: las líneas de cobro siguen la suerte del comprobante. Los totales
    -- de caja ya excluyen las ventas anuladas por su cabecera, pero dejarlas
    -- activas haría que un listado de cobros por cuenta bancaria contara dinero
    -- de una venta que ya no existe.
    UPDATE ven_comprobante_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
;
