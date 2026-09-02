-- Reasigna los inv_movimiento de un documento origen a otro (p.ej. conversión de una
-- venta sin documento (VSD/NV) a un CPE formal): NO crea ni revierte movimientos, solo
-- cambia a qué documento apuntan. Reemplaza el viejo "UPDATE pro_movimientos SET
-- id_documento_ref = ..." que quedó huérfano tras el corte a inv_movimiento.
CREATE OR REPLACE FUNCTION inv_repuntar_documento(
    p_codigo_tipo_documento_origen_actual VARCHAR,
    p_id_documento_origen_actual INTEGER,
    p_codigo_tipo_documento_origen_nuevo VARCHAR,
    p_id_documento_origen_nuevo INTEGER,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc_actual INTEGER;
    v_id_tipo_doc_nuevo INTEGER;
    v_count INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen_actual IS NULL OR p_id_documento_origen_nuevo IS NULL THEN
        RETURN json_build_object('error', 'Documento origen actual y nuevo son obligatorios', 'repuntados', 0);
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_actual
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen_actual, '')))
      AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_nuevo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen_nuevo, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc_actual IS NULL OR v_id_tipo_doc_nuevo IS NULL THEN
        RETURN json_build_object('error', 'Tipo de documento origen no configurado', 'repuntados', 0);
    END IF;

    UPDATE inv_movimiento
    SET id_documento_origen = p_id_documento_origen_nuevo,
        id_tipo_documento_origen = v_id_tipo_doc_nuevo,
        glosa = COALESCE(NULLIF(TRIM(p_glosa), ''), glosa),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_tipo_documento_origen = v_id_tipo_doc_actual
      AND id_documento_origen = p_id_documento_origen_actual
      AND estado = 1;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN json_build_object('repuntados', v_count);
END;
$function$;
