-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_registrar_respuesta_resumen_diario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_registrar_respuesta_resumen_diario(p_id integer, p_id_estado_sunat integer, p_ticket_sunat character varying, p_cdr_respuesta text, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_registrar_respuesta_resumen_diario(p_id integer, p_id_estado_sunat integer DEFAULT NULL::integer, p_ticket_sunat character varying DEFAULT NULL::character varying, p_cdr_respuesta text DEFAULT NULL::text, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM ven_resumen_diario WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_estado_sunat IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_estado_sunat AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El estado SUNAT indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE ven_resumen_diario
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN ven_obtener_resumen_diario(p_id);
END;
$function$;
