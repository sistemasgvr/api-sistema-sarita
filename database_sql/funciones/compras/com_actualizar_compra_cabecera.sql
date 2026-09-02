-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_actualizar_compra_cabecera
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.631Z
DROP FUNCTION IF EXISTS com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying, p_id_condicion_pago integer, p_id_categoria_gasto integer, p_declarar_sunat boolean, p_id_usuario_auditoria integer, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);

CREATE OR REPLACE FUNCTION com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying DEFAULT NULL::character varying, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT NULL::boolean, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$
