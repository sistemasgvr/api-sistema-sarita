-- Function: ven_registrar_respuesta_sunat_percepcion
-- Registrar respuesta de SUNAT para una percepción

CREATE OR REPLACE FUNCTION ven_registrar_respuesta_sunat_percepcion(
    p_id integer,
    p_id_estado_sunat integer DEFAULT NULL,
    p_ticket_sunat character varying DEFAULT NULL,
    p_hash_documento character varying DEFAULT NULL,
    p_xml_firmado text DEFAULT NULL,
    p_cdr_respuesta text DEFAULT NULL,
    p_id_usuario_auditoria integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM ven_percepcion WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE ven_percepcion
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN ven_obtener_percepcion(p_id);
END;
$function$;
