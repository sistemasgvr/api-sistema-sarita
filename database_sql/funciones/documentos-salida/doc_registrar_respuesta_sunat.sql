-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_registrar_respuesta_sunat
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_registrar_respuesta_sunat(p_id integer, p_codigo_estado_sunat character varying, p_ticket_sunat character varying, p_hash_documento character varying, p_xml_firmado text, p_cdr_respuesta text, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_registrar_respuesta_sunat(p_id integer, p_codigo_estado_sunat character varying, p_ticket_sunat character varying DEFAULT NULL::character varying, p_hash_documento character varying DEFAULT NULL::character varying, p_xml_firmado text DEFAULT NULL::text, p_cdr_respuesta text DEFAULT NULL::text, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_id_estado_sunat INTEGER;
    v_codigo VARCHAR;
    v_aceptado BOOLEAN;
    v_id_emitida INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_doc.serie IS NULL OR v_doc.numero_sunat IS NULL THEN
        RETURN json_build_object(
            'error', 'El documento aún no tiene serie y número SUNAT; conviértelo a guía de remisión primero',
            'registro', NULL
        );
    END IF;

    v_codigo := UPPER(TRIM(COALESCE(p_codigo_estado_sunat, '')));

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = v_codigo AND lo.estado = 1;

    IF v_id_estado_sunat IS NULL THEN
        RETURN json_build_object('error', format('Estado SUNAT %s no configurado', v_codigo), 'registro', NULL);
    END IF;

    v_aceptado := v_codigo IN ('ACEPTADO', 'ACEPTADA');

    UPDATE doc_salida
    SET id_estado_sunat = v_id_estado_sunat,
        ticket_sunat = COALESCE(p_ticket_sunat, ticket_sunat),
        hash_documento = COALESCE(p_hash_documento, hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        emitido_sunat = CASE WHEN v_aceptado THEN TRUE ELSE emitido_sunat END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    IF v_aceptado THEN
        SELECT lo.id INTO v_id_emitida
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'EMITIDA_SUNAT' AND lo.estado = 1;

        UPDATE doc_salida SET id_estado_ciclo = v_id_emitida WHERE id = p_id;
    END IF;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
