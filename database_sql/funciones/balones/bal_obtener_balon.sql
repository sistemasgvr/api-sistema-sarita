CREATE OR REPLACE FUNCTION bal_obtener_balon(p_id INTEGER)
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
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            cu.razon_social AS nombre_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            cp.razon_social AS nombre_cliente_propietario,
            b.id_referencia,
            ref.nombre AS nombre_referencia,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.vigencia_ph_anios AS vigencia_ph_tipo_anios,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.fecha_ultima_prueba_hidrostatica,
            b.vigencia_prueba_hidrostatica_anios,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.fecha_fabricacion,
            b.anio_fabricacion,
            b.numero_recepcion,
            b.presion_actual,
            b.observacion,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion,
            b.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            b.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT row_to_json(bj)
                FROM (
                    SELECT
                        bb.id,
                        bb.id_motivo_baja,
                        mb.nombre AS nombre_motivo_baja,
                        bb.fecha_baja,
                        bb.motivo_detalle,
                        bb.id_cliente_comprador,
                        cc.razon_social AS nombre_cliente_comprador,
                        bb.serie_comprobante,
                        bb.numero_comprobante,
                        bb.monto_venta,
                        bb.observacion,
                        bb.id_usuario_solicita,
                        us.nombre AS nombre_usuario_solicita,
                        bb.id_usuario_autoriza,
                        ua.nombre AS nombre_usuario_autoriza,
                        bb.fecha_autorizacion
                    FROM bal_baja_balon bb
                    LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
                    LEFT JOIN cli_clientes cc ON bb.id_cliente_comprador = cc.id
                    LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
                    LEFT JOIN auth_usuarios ua ON bb.id_usuario_autoriza = ua.id
                    WHERE bb.id_balon = b.id AND bb.estado = 1 AND bb.estado_aprobacion = 'APROBADA'
                    LIMIT 1
                ) bj
            ) AS baja
        FROM bal_balon b
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones ref ON b.id_referencia = ref.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN auth_usuarios uc ON b.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON b.id_usuario_modificacion = um.id
        WHERE b.id = p_id AND b.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
