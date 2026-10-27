-- Registra la respuesta de SUNAT de una retención
DROP FUNCTION IF EXISTS public.com_registrar_respuesta_sunat_retencion (
  p_id integer,
  p_id_estado_sunat integer,
  p_ticket_sunat character varying,
  p_hash_documento character varying,
  p_xml_firmado text,
  p_cdr_respuesta text,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.com_registrar_respuesta_sunat_retencion (
  p_id integer,
  p_id_estado_sunat integer DEFAULT NULL::integer,
  p_ticket_sunat character varying DEFAULT NULL::character varying,
  p_hash_documento character varying DEFAULT NULL::character varying,
  p_xml_firmado text DEFAULT NULL::text,
  p_cdr_respuesta text DEFAULT NULL::text,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM com_retencion WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE com_retencion
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN com_obtener_retencion(p_id);
END;
$function$;
