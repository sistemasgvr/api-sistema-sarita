-- Obtiene garantia por id
DROP FUNCTION IF EXISTS public.ven_obtener_garantia (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_obtener_garantia (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            g.id_prestamo_detalle,
            g.id_garantia_origen,
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
            g.monto_transferido,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.id_medio_pago,
            mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.fecha_reembolso,
            g.id_medio_reembolso,
            mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.id_usuario_reembolso,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion,
            CASE
                WHEN g.id_prestamo IS NOT NULL THEN 'PRESTAMO'
                WHEN g.id_alquiler IS NOT NULL THEN 'ALQUILER'
                WHEN EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                ) THEN 'POS'
                ELSE 'MANUAL'
            END AS origen,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS es_manual,
            (g.estado = 1) AS puede_editar,
            cob.numero_operacion,
            COALESCE(cob.fecha, g.fecha_registro) AS cobro_fecha,
            COALESCE(cob.id_medio_pago, g.id_medio_pago) AS cobro_id_medio_pago,
            mpc.nombre AS cobro_medio_pago,
            COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria) AS cobro_id_cuenta_bancaria,
            COALESCE(cbc.alias, cbc.titular, cbc.numero_cuenta) AS cobro_cuenta_bancaria,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_eliminar,
            (
                SELECT CASE
                    WHEN vc.id IS NULL THEN NULL
                    ELSE CONCAT_WS('-', vc.serie, vc.numero)
                END
                FROM ven_garantia_movimiento gm
                LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS comprobante_cobro,
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
                        gm.id_medio_pago,
                        mpm.nombre AS medio_pago,
                        gm.id_cuenta_bancaria,
                        COALESCE(cbm.alias, cbm.titular, cbm.numero_cuenta) AS cuenta_bancaria,
                        gm.numero_operacion,
                        gm.id_sucursal,
                        gm.fecha_creacion
                    FROM ven_garantia_movimiento gm
                    LEFT JOIN gen_lista_opciones tm ON gm.id_tipo_movimiento = tm.id
                    LEFT JOIN ven_comprobante vc ON gm.id_comprobante = vc.id
                    LEFT JOIN gen_lista_opciones mpm ON gm.id_medio_pago = mpm.id
                    LEFT JOIN gen_cuenta_bancaria cbm ON cbm.id = gm.id_cuenta_bancaria
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
        LEFT JOIN gen_lista_opciones mp ON g.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones mr ON g.id_medio_reembolso = mr.id
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        LEFT JOIN LATERAL (
            SELECT gm.fecha, gm.id_medio_pago, gm.id_cuenta_bancaria, gm.numero_operacion
            FROM ven_garantia_movimiento gm
            INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
            WHERE gm.id_garantia = g.id
              AND gm.estado = 1
              AND UPPER(tm.nombre) = 'COBRO'
            ORDER BY gm.fecha ASC, gm.id ASC
            LIMIT 1
        ) cob ON TRUE
        LEFT JOIN gen_lista_opciones mpc ON mpc.id = COALESCE(cob.id_medio_pago, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cbc ON cbc.id = COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria)
        LEFT JOIN auth_usuarios uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON g.id_usuario_modificacion = umod.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
