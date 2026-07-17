CREATE OR REPLACE FUNCTION gre_registrar_respuesta_sunat(
    p_id INTEGER,
    p_ticket_sunat VARCHAR DEFAULT NULL,
    p_hash_documento VARCHAR DEFAULT NULL,
    p_xml_firmado TEXT DEFAULT NULL,
    p_cdr_respuesta TEXT DEFAULT NULL,
    p_nombre_estado_sunat VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_sunat INTEGER;
    v_id_estado_op INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM gre_guia_remision WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'Guía de remisión no encontrada');
    END IF;

    IF p_nombre_estado_sunat IS NOT NULL AND TRIM(p_nombre_estado_sunat) <> '' THEN
        SELECT lo.id INTO v_id_estado_sunat
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoSunat'
          AND lo.nombre = UPPER(TRIM(p_nombre_estado_sunat))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_sunat IS NULL THEN
            RETURN json_build_object('error', format('Estado SUNAT %s no configurado', p_nombre_estado_sunat));
        END IF;
    END IF;

    IF UPPER(TRIM(COALESCE(p_nombre_estado_sunat, ''))) = 'ACEPTADO' THEN
        SELECT lo.id INTO v_id_estado_op
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoGuiaRemision' AND lo.nombre = 'ENVIADO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    UPDATE gre_guia_remision
    SET ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_estado_sunat = COALESCE(v_id_estado_sunat, id_estado_sunat),
        id_estado = COALESCE(v_id_estado_op, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN gre_obtener_guia_remision(p_id);
END;
$function$;
