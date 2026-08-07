CREATE OR REPLACE FUNCTION ven_obtener_garantia(p_id INTEGER)
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
            g.id,
            g.id_cliente,
            c.razon_social AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            pr.titulo AS titulo_prestamo,
            g.id_alquiler,
            al.numero_alquiler,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.precio_garantia AS precio_garantia_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion,
            g.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            g.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            (
                SELECT COALESCE(json_agg(row_to_json(m) ORDER BY m.fecha DESC, m.id DESC), '[]'::JSON)
                FROM (
                    SELECT
                        gm.id,
                        gm.id_garantia,
                        gm.id_tipo_movimiento,
                        tm.nombre AS nombre_tipo_movimiento,
                        gm.id_comprobante,
                        vc.serie AS serie_comprobante,
                        vc.numero AS numero_comprobante,
                        CASE
                            WHEN vc.id IS NULL THEN NULL
                            ELSE CONCAT_WS('-', vc.serie, vc.numero)
                        END AS comprobante,
                        gm.fecha,
                        gm.monto,
                        gm.observacion,
                        gm.fecha_creacion
                    FROM ven_garantia_movimiento gm
                    LEFT JOIN gen_lista_opciones tm ON gm.id_tipo_movimiento = tm.id
                    LEFT JOIN ven_comprobante vc ON gm.id_comprobante = vc.id
                    WHERE gm.id_garantia = g.id AND gm.estado = 1
                ) m
            ) AS movimientos
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON g.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN auth_usuarios uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON g.id_usuario_modificacion = umod.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
