-- Shared by the form, list and BOTH mutation paths. No external SUNAT calls.
CREATE OR REPLACE FUNCTION public.ven_comprobante_permite_edicion(c ven_comprobante)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE v_tipo text; v_estado text; v_payload jsonb; v_respuesta jsonb; v_codigo text; v_rechazo boolean:=false;
BEGIN
    IF c.estado<>1 THEN RETURN false; END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id=c.id_tipo_comprobante;
    IF v_tipo IN ('VSD','NV') THEN
        RETURN NOT EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen=c.id AND estado=1);
    END IF;
    IF v_tipo NOT IN ('01','03') THEN RETURN false; END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id=c.id_estado_sunat;
    IF COALESCE(v_estado,'') NOT IN ('PENDIENTE','RECHAZADO') OR ven_cpe_validez_aceptada(c) THEN RETURN false; END IF;
    IF position('emision_por_confirmar' IN COALESCE(c.cdr_respuesta,''))>0 THEN RETURN false; END IF;
    -- A pending label alone is insufficient if an emission has already left evidence.
    IF v_estado='PENDIENTE' AND (
        NULLIF(btrim(c.ticket_sunat),'') IS NOT NULL
        OR c.hash_documento IS NOT NULL OR c.xml_firmado IS NOT NULL OR c.cdr_respuesta IS NOT NULL
    ) THEN RETURN false; END IF;
    -- Existing rejection correction remains possible only with a definite recorded result.
    IF v_estado='RECHAZADO' THEN
        IF NULLIF(btrim(c.cdr_respuesta),'') IS NULL OR NULLIF(btrim(c.ticket_sunat),'') IS NOT NULL THEN RETURN false; END IF;
        BEGIN v_payload:=c.cdr_respuesta::jsonb;
        EXCEPTION WHEN invalid_text_representation THEN RETURN false;
        END;
        v_respuesta:=COALESCE(v_payload->'sunatResponse',v_payload);
        v_codigo:=NULLIF(btrim(v_respuesta#>>'{cdrResponse,code}'),'');
        -- Same definitive rejection codes as common/helpers/cpe-estado.helper.ts.
        IF v_codigo IS NOT NULL THEN
            IF v_codigo !~ '^[0-9]{1,8}$' THEN RETURN false; END IF;
            v_rechazo:=v_codigo::numeric=99 OR v_codigo::numeric BETWEEN 2000 AND 3999;
        ELSIF v_respuesta#>'{cdrResponse,accepted}'='false'::jsonb THEN
            v_rechazo:=true;
        ELSIF v_respuesta#>'{cdrResponse,accepted}'='true'::jsonb THEN
            RETURN false;
        ELSE
            v_codigo:=NULLIF(btrim(v_respuesta#>>'{error,code}'),'');
            IF v_codigo IS NOT NULL AND v_codigo ~ '^[0-9]{1,8}$' THEN
                v_rechazo:=v_codigo::numeric BETWEEN 2000 AND 3999;
            END IF;
        END IF;
        IF NOT v_rechazo THEN RETURN false; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM ven_resumen_diario_detalle rd
        JOIN ven_resumen_diario r ON r.id=rd.id_resumen AND r.estado=1
        LEFT JOIN gen_lista_opciones er ON er.id=r.id_estado_sunat
        WHERE rd.id_comprobante=c.id AND rd.estado=1 AND COALESCE(er.nombre,'')<>'RECHAZADO') THEN RETURN false; END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen=c.id AND estado=1) THEN RETURN false; END IF;
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.ven_validar_edicion_pre_emision(p_id integer)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_doc ven_comprobante%ROWTYPE; v_tipo text;
BEGIN
    -- Same advisory key held across the complete external emission request.
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
$$;
