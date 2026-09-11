-- ============================================================
-- Migración: GRE — la orden anulada no llega a SUNAT
-- Fecha: 2026-09-10
--
-- Acompaña al arreglo del destinatario de planta externa en la API
-- (doc-salida-despatch.mapper.ts), que no toca base de datos: en recarga o
-- retorno de planta externa el destinatario de la guía es el proveedor, y el
-- mapper solo miraba documento_destinatario.
--
-- Lo único que sí necesita SQL es el corte por ciclo. Anular una orden no
-- borra su serie ni su correlativo SUNAT, así que un documento ANULADA seguía
-- pasando todas las validaciones de emisión: se enviaba a SUNAT la guía de un
-- traslado que ya no existe y deshacerlo obliga a una comunicación de baja.
-- La API también lo rechaza antes de llamar al PSE; esta guarda cierra el
-- camino por si la respuesta llega por otra vía.
--
-- No cambia firmas.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_gre_planta_destinatario_emit.sql
-- ============================================================


-- ------------------------------------------------------------
-- doc_registrar_respuesta_sunat: rechaza documentos anulados
-- ------------------------------------------------------------
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

    -- La anulación no limpia serie ni numero_sunat: sin este corte la guía de
    -- un traslado ya deshecho seguía viajando a SUNAT.
    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object(
            'error', 'El documento está anulado: no puede emitirse a SUNAT',
            'registro', NULL
        );
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
