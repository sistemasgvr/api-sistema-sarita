CREATE OR REPLACE FUNCTION bal_obtener_movimiento(p_id INTEGER)
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
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN COALESCE(
                    NULLIF(CONCAT_WS('-', NULLIF(mr.serie_factura, ''), NULLIF(mr.numero_factura, '')), ''),
                    NULLIF(mr.lote, ''),
                    'Recarga #' || mr.id::TEXT
                )
                WHEN 'ALQUILER' THEN COALESCE(alq.numero_alquiler, 'Alquiler #' || alq.id::TEXT)
                WHEN 'PRESTAMO' THEN COALESCE(pr.numero_prestamo, 'Préstamo #' || pr.id::TEXT)
                WHEN 'MANTENIMIENTO' THEN 'Mantenimiento #' || mt.id::TEXT
                WHEN 'GRE' THEN CONCAT_WS('-', gre.serie, gre.numero)
                WHEN 'FACTURA' THEN COALESCE(
                    CONCAT_WS('-', vc.serie, vc.numero),
                    CASE WHEN mt.id IS NOT NULL THEN 'Mantenimiento #' || mt.id::TEXT END
                )
                WHEN 'BOLETA' THEN CONCAT_WS('-', vc.serie, vc.numero)
                WHEN 'NOTA_CREDITO' THEN CONCAT_WS('-', vc.serie, vc.numero)
                WHEN 'NOTA_DEBITO' THEN CONCAT_WS('-', vc.serie, vc.numero)
                WHEN 'NOTA_VENTA' THEN CONCAT_WS('-', vc.serie, vc.numero)
                ELSE NULL
            END AS documento_numero,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN mr.fecha_salida_almacen::TEXT
                WHEN 'ALQUILER' THEN alq.fecha_inicio::TEXT
                WHEN 'PRESTAMO' THEN pr.fecha_salida::TEXT
                WHEN 'MANTENIMIENTO' THEN mt.fecha_ingreso::TEXT
                WHEN 'GRE' THEN gre.fecha::TEXT
                WHEN 'FACTURA' THEN COALESCE(vc.fecha::TEXT, mt.fecha_ingreso::TEXT)
                WHEN 'BOLETA' THEN vc.fecha::TEXT
                WHEN 'NOTA_CREDITO' THEN vc.fecha::TEXT
                WHEN 'NOTA_DEBITO' THEN vc.fecha::TEXT
                WHEN 'NOTA_VENTA' THEN vc.fecha::TEXT
                ELSE NULL
            END AS documento_fecha,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN mr_cli.razon_social
                WHEN 'ALQUILER' THEN alq_cli.razon_social
                WHEN 'PRESTAMO' THEN COALESCE(pr_cli.razon_social, pr_prov.razon_social)
                WHEN 'MANTENIMIENTO' THEN COALESCE(mt_vc_cli.razon_social, mt_prov.razon_social)
                WHEN 'GRE' THEN gre_cli.razon_social
                WHEN 'FACTURA' THEN COALESCE(vc_cli.razon_social, mt_prov.razon_social)
                WHEN 'BOLETA' THEN vc_cli.razon_social
                WHEN 'NOTA_CREDITO' THEN vc_cli.razon_social
                WHEN 'NOTA_DEBITO' THEN vc_cli.razon_social
                WHEN 'NOTA_VENTA' THEN vc_cli.razon_social
                ELSE NULL
            END AS documento_cliente,
            CASE
                WHEN tdr.nombre = 'RECARGA' THEN mr.lote
                ELSE NULL
            END AS documento_lote,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(mr_tipo.nombre, ''),
                    NULLIF(mr_prod.nombre, ''),
                    CASE
                        WHEN mr.serie_guia_salida IS NOT NULL AND mr.numero_guia_salida IS NOT NULL
                        THEN 'Guía salida ' || mr.serie_guia_salida || '-' || mr.numero_guia_salida
                        ELSE NULL
                    END
                ), '')
                WHEN 'ALQUILER' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    CASE WHEN alq.fecha_fin_pactada IS NOT NULL
                        THEN 'Fin pactado ' || alq.fecha_fin_pactada::TEXT
                        ELSE NULL
                    END,
                    CASE WHEN alq_vc.id IS NOT NULL
                        THEN 'Comprobante ' || CONCAT_WS('-', alq_vc.serie, alq_vc.numero)
                        ELSE NULL
                    END,
                    NULLIF(alq.observacion, '')
                ), '')
                WHEN 'PRESTAMO' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(pr.titulo, ''),
                    NULLIF(pr_tipo.nombre, ''),
                    CASE WHEN pr_vc.id IS NOT NULL
                        THEN 'Comprobante ' || CONCAT_WS('-', pr_vc.serie, pr_vc.numero)
                        ELSE NULL
                    END,
                    NULLIF(pr.observacion, '')
                ), '')
                WHEN 'MANTENIMIENTO' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(mt_tipo.nombre, ''),
                    NULLIF(mt.descripcion, ''),
                    CASE WHEN mt_vc.id IS NOT NULL
                        THEN 'Comprobante ' || CONCAT_WS('-', mt_vc.serie, mt_vc.numero)
                        ELSE NULL
                    END
                ), '')
                WHEN 'GRE' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(gre_motivo.nombre, ''),
                    CASE WHEN gre.fecha_traslado IS NOT NULL
                        THEN 'Traslado ' || gre.fecha_traslado::TEXT
                        ELSE NULL
                    END
                ), '')
                WHEN 'FACTURA' THEN COALESCE(
                    NULLIF(CONCAT_WS(' · ', NULLIF(vc_tipo.nombre, ''), 'Total ' || COALESCE(vc.total_importe::TEXT, '0')), ''),
                    NULLIF(CONCAT_WS(' · ', NULLIF(mt_tipo.nombre, ''), NULLIF(mt.descripcion, '')), '')
                )
                WHEN 'BOLETA' THEN NULLIF(CONCAT_WS(' · ', NULLIF(vc_tipo.nombre, ''), 'Total ' || COALESCE(vc.total_importe::TEXT, '0')), '')
                WHEN 'NOTA_CREDITO' THEN NULLIF(CONCAT_WS(' · ', NULLIF(vc_tipo.nombre, ''), 'Total ' || COALESCE(vc.total_importe::TEXT, '0')), '')
                WHEN 'NOTA_DEBITO' THEN NULLIF(CONCAT_WS(' · ', NULLIF(vc_tipo.nombre, ''), 'Total ' || COALESCE(vc.total_importe::TEXT, '0')), '')
                WHEN 'NOTA_VENTA' THEN NULLIF(CONCAT_WS(' · ', NULLIF(vc_tipo.nombre, ''), 'Total ' || COALESCE(vc.total_importe::TEXT, '0')), '')
                ELSE NULL
            END AS documento_detalle,
            m.id_cliente,
            c.razon_social AS nombre_cliente,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.fecha_movimiento,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_movimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN cli_clientes c ON m.id_cliente = c.id
        LEFT JOIN gen_almacen ao ON m.id_almacen_origen = ao.id
        LEFT JOIN gen_almacen ad ON m.id_almacen_destino = ad.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        LEFT JOIN bal_movimiento_recarga mr
            ON tdr.nombre = 'RECARGA'
           AND mr.id = m.id_documento_ref
        LEFT JOIN cli_clientes mr_cli ON mr.id_cliente = mr_cli.id
        LEFT JOIN pro_producto mr_prod ON mr.id_producto = mr_prod.id
        LEFT JOIN gen_lista_opciones mr_tipo ON mr.id_tipo_recarga = mr_tipo.id
        LEFT JOIN bal_alquiler alq
            ON tdr.nombre = 'ALQUILER'
           AND alq.id = m.id_documento_ref
        LEFT JOIN cli_clientes alq_cli ON alq.id_cliente = alq_cli.id
        LEFT JOIN ven_comprobante alq_vc ON alq.id_comprobante_venta = alq_vc.id
        LEFT JOIN bal_prestamo pr
            ON tdr.nombre = 'PRESTAMO'
           AND pr.id = m.id_documento_ref
        LEFT JOIN cli_clientes pr_cli ON pr.id_cliente = pr_cli.id
        LEFT JOIN cli_clientes pr_prov ON pr.id_proveedor = pr_prov.id
        LEFT JOIN gen_lista_opciones pr_tipo ON pr.id_tipo_prestamo = pr_tipo.id
        LEFT JOIN ven_comprobante pr_vc ON pr.id_comprobante_venta = pr_vc.id
        LEFT JOIN gre_guia_remision gre
            ON tdr.nombre = 'GRE'
           AND gre.id = m.id_documento_ref
        LEFT JOIN cli_clientes gre_cli ON gre.id_cliente = gre_cli.id
        LEFT JOIN gen_lista_opciones gre_motivo ON gre.id_motivo_traslado = gre_motivo.id
        LEFT JOIN ven_comprobante vc
            ON tdr.nombre IN ('FACTURA', 'BOLETA', 'NOTA_CREDITO', 'NOTA_DEBITO', 'NOTA_VENTA')
           AND vc.id = m.id_documento_ref
        LEFT JOIN cli_clientes vc_cli ON vc.id_cliente = vc_cli.id
        LEFT JOIN gen_lista_opciones vc_tipo ON vc.id_tipo_comprobante = vc_tipo.id
        LEFT JOIN bal_mantenimiento mt
            ON (
                tdr.nombre = 'MANTENIMIENTO'
                OR (tdr.nombre = 'FACTURA' AND vc.id IS NULL)
            )
           AND mt.id = m.id_documento_ref
        LEFT JOIN cli_clientes mt_prov ON mt.id_proveedor = mt_prov.id
        LEFT JOIN gen_lista_opciones mt_tipo ON mt.id_tipo_mantenimiento = mt_tipo.id
        LEFT JOIN ven_comprobante mt_vc ON mt.id_comprobante_venta = mt_vc.id
        LEFT JOIN cli_clientes mt_vc_cli ON mt_vc.id_cliente = mt_vc_cli.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
