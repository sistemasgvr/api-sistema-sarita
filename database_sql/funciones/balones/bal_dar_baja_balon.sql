CREATE OR REPLACE FUNCTION bal_dar_baja_balon(
    p_id_balon INTEGER,
    p_id_motivo_baja INTEGER,
    p_id_usuario_solicita INTEGER,
    p_id_usuario_autoriza INTEGER DEFAULT NULL,
    p_motivo_detalle VARCHAR DEFAULT NULL,
    p_id_cliente_comprador INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_serie_comprobante VARCHAR DEFAULT NULL,
    p_numero_comprobante VARCHAR DEFAULT NULL,
    p_monto_venta NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_fecha_baja DATE DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN bal_solicitar_baja_balon(
        p_id_balon,
        p_id_motivo_baja,
        p_id_usuario_solicita,
        p_motivo_detalle,
        p_id_cliente_comprador,
        p_id_comprobante_venta,
        p_serie_comprobante,
        p_numero_comprobante,
        p_monto_venta,
        p_observacion,
        p_fecha_baja,
        p_id_usuario_auditoria
    );
END;
$function$;
