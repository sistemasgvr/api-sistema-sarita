-- Campos administrativos que NO afectan inventario.
-- Se permiten aunque la compra ya haya generado ingresos de stock.

CREATE OR REPLACE FUNCTION com_actualizar_compra_cabecera(
    p_id_comprobante         INTEGER,
    p_glosa                  VARCHAR DEFAULT NULL,
    p_id_condicion_pago      INTEGER DEFAULT NULL,
    p_id_categoria_gasto     INTEGER DEFAULT NULL,
    p_declarar_sunat         BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
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

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;
