-- Bloquea la edición de un comprobante con emisión en curso o ya enviada
DROP FUNCTION IF EXISTS public.ven_validar_edicion_pre_emision (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_validar_edicion_pre_emision (p_id integer) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE v_doc ven_comprobante%ROWTYPE; v_tipo text;
BEGIN
    IF NOT pg_try_advisory_xact_lock(872016,p_id) THEN
        RAISE EXCEPTION 'Hay una emisión en curso para este comprobante. Espere su resultado antes de editar';
    END IF;
    SELECT * INTO v_doc FROM ven_comprobante WHERE id=p_id AND estado=1 FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id=v_doc.id_tipo_comprobante;
    IF v_tipo IN ('01','03') AND NOT ven_comprobante_permite_edicion(v_doc) THEN
        RAISE EXCEPTION 'La factura o boleta ya tiene una emisión, un envío por confirmar o documentos vinculados. Verifique su estado antes de corregir';
    END IF;
END;
$function$;
