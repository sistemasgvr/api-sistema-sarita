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
-- solo cambia su estado de ciclo a ANULADA. Ver también doc_obtener_salida.sql
-- (ahora sigue mostrando el detalle de una venta anulada, en vez de vaciarlo).
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
    v_serie VARCHAR;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, c.serie, c.numero
    INTO v_estado_sunat, v_serie, v_numero
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

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Cascada: cualquier documento de salida vigente originado en esta venta
    -- queda anulado también (no mueve inventario propio: solo cambia estado).
    PERFORM doc_anular_salida(
        d.id,
        format('Venta %s-%s anulada', COALESCE(v_serie, ''), COALESCE(v_numero, p_id::text)),
        p_id_usuario_auditoria
    )
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id_venta = p_id
      AND d.estado = 1
      AND ec.nombre <> 'ANULADA';

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$
;
