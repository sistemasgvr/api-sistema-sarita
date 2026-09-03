-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_pos_crear_guia_remision
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_pos_crear_guia_remision(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_pos_crear_guia_remision(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN;
    END IF;

    -- Idempotente: si la venta ya tiene un documento de salida vigente no se crea otro.
    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id_comprobante
          AND d.estado = 1
          AND ec.nombre <> 'ANULADA'
    ) THEN
        RETURN;
    END IF;

    v_resultado := doc_crear_desde_venta(
        p_id_venta             => p_id_comprobante,
        p_id_usuario_auditoria => p_id_usuario
    );

    IF v_resultado->>'error' IS NOT NULL THEN
        RAISE NOTICE 'No se generó el documento de salida de la venta %: %',
            p_id_comprobante, v_resultado->>'error';
    END IF;
END;
$function$;
