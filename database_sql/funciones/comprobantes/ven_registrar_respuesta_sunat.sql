CREATE OR REPLACE FUNCTION ven_registrar_respuesta_sunat(
    p_id INTEGER,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_ticket_sunat VARCHAR DEFAULT NULL,
    p_hash_documento VARCHAR DEFAULT NULL,
    p_xml_firmado TEXT DEFAULT NULL,
    p_cdr_respuesta TEXT DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_estado_sunat IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_estado_sunat AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El estado SUNAT indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT nombre INTO v_estado_sunat_nombre
    FROM gen_lista_opciones
    WHERE id = p_id_estado_sunat;

    UPDATE ven_comprobante
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_estado_sunat_nombre = 'ACEPTADO' THEN
        UPDATE ven_comprobante c
        SET id_estado = lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE c.id = p_id
          AND l.nombre = 'EstadoDocumento'
          AND lo.nombre = 'PAGADO'
          AND lo.estado = 1
          AND c.id_estado IS DISTINCT FROM lo.id;
    END IF;

    RETURN ven_obtener_comprobante(p_id);
END;
$function$;
