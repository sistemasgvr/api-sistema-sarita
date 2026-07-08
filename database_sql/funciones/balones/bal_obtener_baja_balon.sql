CREATE OR REPLACE FUNCTION bal_obtener_baja_balon(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            bb.id,
            bb.id_balon,
            b.codigo_balon,
            b.numero_serie,
            bb.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            bb.fecha_baja,
            bb.motivo_detalle,
            bb.id_cliente_comprador,
            cc.razon_social AS nombre_cliente_comprador,
            bb.id_comprobante_venta,
            bb.serie_comprobante,
            bb.numero_comprobante,
            bb.monto_venta,
            bb.id_movimiento,
            bb.observacion,
            bb.id_usuario_solicita,
            us.nombre AS nombre_usuario_solicita,
            bb.id_usuario_autoriza,
            ua.nombre AS nombre_usuario_autoriza,
            bb.fecha_autorizacion,
            bb.estado,
            bb.fecha_creacion,
            bb.fecha_modificacion
        FROM bal_baja_balon bb
        INNER JOIN bal_balon b ON bb.id_balon = b.id
        LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
        LEFT JOIN cli_clientes cc ON bb.id_cliente_comprador = cc.id
        LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
        LEFT JOIN auth_usuarios ua ON bb.id_usuario_autoriza = ua.id
        WHERE bb.id = p_id AND bb.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
