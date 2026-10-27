-- Crea el documento de salida de una venta POS si aún no tiene uno
DROP FUNCTION IF EXISTS public.ven_pos_crear_guia_remision (p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.ven_pos_crear_guia_remision (
  p_id_comprobante integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS void LANGUAGE plpgsql AS $function$
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
