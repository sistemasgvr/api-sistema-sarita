-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_crear_resumen_diario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_crear_resumen_diario(p_fecha date, p_correlativo character varying, p_ticket_sunat character varying, p_id_estado_sunat integer, p_cdr_respuesta text, p_moneda character varying, p_cantidad_docs integer, p_total_importe numeric, p_total_igv numeric, p_total_valor_venta numeric, p_ids_comprobante json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_crear_resumen_diario(p_fecha date, p_correlativo character varying, p_ticket_sunat character varying DEFAULT NULL::character varying, p_id_estado_sunat integer DEFAULT NULL::integer, p_cdr_respuesta text DEFAULT NULL::text, p_moneda character varying DEFAULT 'PEN'::character varying, p_cantidad_docs integer DEFAULT 0, p_total_importe numeric DEFAULT 0, p_total_igv numeric DEFAULT 0, p_total_valor_venta numeric DEFAULT 0, p_ids_comprobante json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_correlativo VARCHAR(10);
    v_identificador VARCHAR(50);
    v_ids INTEGER[];
    v_item INTEGER := 0;
    v_id_comp INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del resumen es obligatoria', 'registro', NULL);
    END IF;

    v_correlativo := LPAD(regexp_replace(COALESCE(NULLIF(TRIM(p_correlativo), ''), '001'), '\D', '', 'g'), 3, '0');
    v_identificador := 'RC-' || to_char(p_fecha, 'YYYYMMDD') || '-' || v_correlativo;

    IF EXISTS (
        SELECT 1 FROM ven_resumen_diario
        WHERE estado = 1 AND fecha = p_fecha AND correlativo = v_correlativo
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe un resumen con correlativo ' || v_correlativo || ' para esa fecha',
            'registro',
            NULL
        );
    END IF;

    SELECT COALESCE(array_agg((value::TEXT)::INTEGER), ARRAY[]::INTEGER[])
    INTO v_ids
    FROM json_array_elements_text(COALESCE(p_ids_comprobante, '[]'::JSON));

    IF COALESCE(array_length(v_ids, 1), 0) = 0 THEN
        RETURN json_build_object('error', 'El resumen debe incluir al menos un comprobante', 'registro', NULL);
    END IF;

    INSERT INTO ven_resumen_diario (
        fecha,
        correlativo,
        identificador,
        ticket_sunat,
        id_estado_sunat,
        cdr_respuesta,
        moneda,
        cantidad_docs,
        total_importe,
        total_igv,
        total_valor_venta,
        id_usuario_creacion,
        id_usuario_modificacion
    ) VALUES (
        p_fecha,
        v_correlativo,
        v_identificador,
        NULLIF(TRIM(p_ticket_sunat), ''),
        p_id_estado_sunat,
        p_cdr_respuesta,
        COALESCE(NULLIF(TRIM(p_moneda), ''), 'PEN'),
        COALESCE(p_cantidad_docs, array_length(v_ids, 1)),
        COALESCE(p_total_importe, 0),
        COALESCE(p_total_igv, 0),
        COALESCE(p_total_valor_venta, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOREACH v_id_comp IN ARRAY v_ids LOOP
        v_item := v_item + 1;
        INSERT INTO ven_resumen_diario_detalle (
            id_resumen,
            id_comprobante,
            item,
            id_usuario_creacion,
            id_usuario_modificacion
        ) VALUES (
            v_id,
            v_id_comp,
            v_item,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    RETURN ven_obtener_resumen_diario(v_id);
END;
$function$;
