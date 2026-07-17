CREATE OR REPLACE FUNCTION bal_obtener_alquiler(p_id INTEGER)
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
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            c.razon_social AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.observacion,
            al.id_comprobante_venta,
            al.estado,
            al.fecha_creacion,
            al.fecha_modificacion,
            al.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            al.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = al.id AND ad.estado = 1
            ) AS total_detalles
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN auth_usuarios uc ON al.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON al.id_usuario_modificacion = um.id
        WHERE al.id = p_id AND al.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
