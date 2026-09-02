-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_movimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.586Z
DROP FUNCTION IF EXISTS bal_obtener_movimiento(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_movimiento(p_id integer)
 RETURNS json
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
                    NULLIF(CONCAT_WS('-', NULLIF(cc.serie, ''), NULLIF(cc.numero, '')), ''),
                    NULLIF(CONCAT_WS('-', NULLIF(mr.serie_factura, ''), NULLIF(mr.numero_factura, '')), ''),
                    NULLIF(CONCAT_WS('-', NULLIF(mr_linea.serie_factura, ''), NULLIF(mr_linea.numero_factura, '')), ''),
                    NULLIF(CONCAT_WS('-', NULLIF(rp.serie_factura, ''), NULLIF(rp.numero_factura, '')), ''),
                    NULLIF(TRIM(rp.numero), ''),
                    NULLIF(mr.lote, ''),
                    NULLIF(mr_linea.lote, ''),
                    CASE
                        WHEN mr.id IS NOT NULL THEN 'Recarga #' || mr.id::TEXT
                        WHEN rp.id IS NOT NULL THEN 'Orden ' || COALESCE(NULLIF(TRIM(rp.numero), ''), '#' || rp.id::TEXT)
                        ELSE NULL
                    END
                )
                WHEN 'ALQUILER' THEN COALESCE(alq.numero_alquiler, 'Alquiler #' || alq.id::TEXT)
                WHEN 'PRESTAMO' THEN COALESCE(pr.numero_prestamo, 'Préstamo #' || pr.id::TEXT)
                WHEN 'MANTENIMIENTO' THEN 'Mantenimiento #' || mt.id::TEXT
                WHEN 'GRE' THEN CONCAT_WS('-', gre.serie, gre.numero)
                WHEN 'COMPRA' THEN CONCAT_WS('-', cc_doc.serie, cc_doc.numero)
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
                WHEN 'RECARGA' THEN COALESCE(
                    cc.fecha::TEXT,
                    mr.fecha_salida_almacen::TEXT,
                    mr_linea.fecha_salida_almacen::TEXT,
                    rp.fecha_salida::TEXT,
                    rp.fecha_llegada_almacen::TEXT
                )
                WHEN 'ALQUILER' THEN alq.fecha_inicio::TEXT
                WHEN 'PRESTAMO' THEN pr.fecha_salida::TEXT
                WHEN 'MANTENIMIENTO' THEN mt.fecha_ingreso::TEXT
                WHEN 'GRE' THEN gre.fecha::TEXT
                WHEN 'COMPRA' THEN cc_doc.fecha::TEXT
                WHEN 'FACTURA' THEN COALESCE(vc.fecha::TEXT, mt.fecha_ingreso::TEXT)
                WHEN 'BOLETA' THEN vc.fecha::TEXT
                WHEN 'NOTA_CREDITO' THEN vc.fecha::TEXT
                WHEN 'NOTA_DEBITO' THEN vc.fecha::TEXT
                WHEN 'NOTA_VENTA' THEN vc.fecha::TEXT
                ELSE NULL
            END AS documento_fecha,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN COALESCE(
                    NULLIF(TRIM(rp_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', rp_prov.nombres, rp_prov.apellido_paterno, rp_prov.apellido_materno)), ''),
                    rp_prov.numero_documento,
                    NULLIF(TRIM(mr_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', mr_prov.nombres, mr_prov.apellido_paterno, mr_prov.apellido_materno)), ''),
                    mr_prov.numero_documento,
                    NULLIF(TRIM(mr_linea_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', mr_linea_prov.nombres, mr_linea_prov.apellido_paterno, mr_linea_prov.apellido_materno)), ''),
                    mr_linea_prov.numero_documento,
                    NULLIF(TRIM(cc_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', cc_prov.nombres, cc_prov.apellido_paterno, cc_prov.apellido_materno)), ''),
                    cc_prov.numero_documento,
                    NULLIF(TRIM(c.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                    c.numero_documento
                )
                WHEN 'ALQUILER' THEN COALESCE(
                    NULLIF(TRIM(alq_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', alq_cli.nombres, alq_cli.apellido_paterno, alq_cli.apellido_materno)), ''),
                    alq_cli.numero_documento
                )
                WHEN 'PRESTAMO' THEN COALESCE(
                    NULLIF(TRIM(pr_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', pr_cli.nombres, pr_cli.apellido_paterno, pr_cli.apellido_materno)), ''),
                    pr_cli.numero_documento,
                    NULLIF(TRIM(pr_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', pr_prov.nombres, pr_prov.apellido_paterno, pr_prov.apellido_materno)), ''),
                    pr_prov.numero_documento
                )
                WHEN 'MANTENIMIENTO' THEN COALESCE(
                    NULLIF(TRIM(mt_vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', mt_vc_cli.nombres, mt_vc_cli.apellido_paterno, mt_vc_cli.apellido_materno)), ''),
                    mt_vc_cli.numero_documento,
                    NULLIF(TRIM(mt_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', mt_prov.nombres, mt_prov.apellido_paterno, mt_prov.apellido_materno)), ''),
                    mt_prov.numero_documento
                )
                WHEN 'GRE' THEN COALESCE(
                    NULLIF(TRIM(gre_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', gre_cli.nombres, gre_cli.apellido_paterno, gre_cli.apellido_materno)), ''),
                    gre_cli.numero_documento
                )
                WHEN 'COMPRA' THEN COALESCE(
                    NULLIF(TRIM(cc_doc_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', cc_doc_prov.nombres, cc_doc_prov.apellido_paterno, cc_doc_prov.apellido_materno)), ''),
                    cc_doc_prov.numero_documento
                )
                WHEN 'FACTURA' THEN COALESCE(
                    NULLIF(TRIM(vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', vc_cli.nombres, vc_cli.apellido_paterno, vc_cli.apellido_materno)), ''),
                    vc_cli.numero_documento,
                    NULLIF(TRIM(mt_prov.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', mt_prov.nombres, mt_prov.apellido_paterno, mt_prov.apellido_materno)), ''),
                    mt_prov.numero_documento
                )
                WHEN 'BOLETA' THEN COALESCE(
                    NULLIF(TRIM(vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', vc_cli.nombres, vc_cli.apellido_paterno, vc_cli.apellido_materno)), ''),
                    vc_cli.numero_documento
                )
                WHEN 'NOTA_CREDITO' THEN COALESCE(
                    NULLIF(TRIM(vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', vc_cli.nombres, vc_cli.apellido_paterno, vc_cli.apellido_materno)), ''),
                    vc_cli.numero_documento
                )
                WHEN 'NOTA_DEBITO' THEN COALESCE(
                    NULLIF(TRIM(vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', vc_cli.nombres, vc_cli.apellido_paterno, vc_cli.apellido_materno)), ''),
                    vc_cli.numero_documento
                )
                WHEN 'NOTA_VENTA' THEN COALESCE(
                    NULLIF(TRIM(vc_cli.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', vc_cli.nombres, vc_cli.apellido_paterno, vc_cli.apellido_materno)), ''),
                    vc_cli.numero_documento
                )
                ELSE NULL
            END AS documento_cliente,
            CASE
                WHEN tdr.nombre = 'RECARGA' THEN COALESCE(mr.lote, mr_linea.lote, rp.lote, rpd.lote)
                ELSE NULL
            END AS documento_lote,
            CASE tdr.nombre
                WHEN 'RECARGA' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(COALESCE(mr_tipo.nombre, mr_linea_tipo.nombre), ''),
                    NULLIF(COALESCE(mr_prod.nombre, mr_linea_prod.nombre, rpd_prod.nombre), ''),
                    CASE
                        WHEN rp.numero IS NOT NULL THEN 'Orden ' || rp.numero
                        ELSE NULL
                    END,
                    CASE
                        WHEN COALESCE(mr.serie_guia_salida, mr_linea.serie_guia_salida, rp.serie_guia_salida, rp_gre_salida.serie) IS NOT NULL
                         AND COALESCE(mr.numero_guia_salida, mr_linea.numero_guia_salida, rp.numero_guia_salida, rp_gre_salida.numero) IS NOT NULL
                        THEN 'Guía salida '
                            || COALESCE(mr.serie_guia_salida, mr_linea.serie_guia_salida, rp.serie_guia_salida, rp_gre_salida.serie)
                            || '-'
                            || COALESCE(mr.numero_guia_salida, mr_linea.numero_guia_salida, rp.numero_guia_salida, rp_gre_salida.numero)
                        ELSE NULL
                    END
                ), '')
                WHEN 'COMPRA' THEN NULLIF(CONCAT_WS(
                    ' · ',
                    NULLIF(COALESCE(rpd_prod.nombre, mr_linea_prod.nombre, mr_prod.nombre), ''),
                    CASE
                        WHEN rp_compra.numero IS NOT NULL THEN 'Orden planta ' || rp_compra.numero
                        WHEN rp_compra.id IS NOT NULL THEN 'Orden planta #' || rp_compra.id::TEXT
                        ELSE NULL
                    END,
                    CASE
                        WHEN COALESCE(rp_compra.serie_guia_salida, rp_compra_gre_salida.serie) IS NOT NULL
                         AND COALESCE(rp_compra.numero_guia_salida, rp_compra_gre_salida.numero) IS NOT NULL
                        THEN 'Guía salida '
                            || COALESCE(rp_compra.serie_guia_salida, rp_compra_gre_salida.serie)
                            || '-'
                            || COALESCE(rp_compra.numero_guia_salida, rp_compra_gre_salida.numero)
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
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento,
                NULLIF(TRIM(rp_prov.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', rp_prov.nombres, rp_prov.apellido_paterno, rp_prov.apellido_materno)), ''),
                rp_prov.numero_documento,
                NULLIF(TRIM(mr_prov.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', mr_prov.nombres, mr_prov.apellido_paterno, mr_prov.apellido_materno)), ''),
                mr_prov.numero_documento,
                NULLIF(TRIM(mr_linea_prov.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', mr_linea_prov.nombres, mr_linea_prov.apellido_paterno, mr_linea_prov.apellido_materno)), ''),
                mr_linea_prov.numero_documento
            ) AS nombre_cliente,
            m.id_almacen_origen,
            COALESCE(
                ao.nombre,
                CASE
                    WHEN tm.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
                    THEN 'Planta externa'
                    ELSE NULL
                END
            ) AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.fecha_movimiento,
            m.observacion,
            m.id_estado_balon,
            eb_snap.nombre AS nombre_estado_balon,
            m.id_almacen_ubicacion,
            au_snap.nombre AS nombre_almacen_ubicacion,
            m.id_cliente_ubicacion,
            COALESCE(
                NULLIF(TRIM(cu_snap.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cu_snap.nombres, cu_snap.apellido_paterno, cu_snap.apellido_materno)), ''),
                cu_snap.numero_documento
            ) AS nombre_cliente_ubicacion,
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
        LEFT JOIN gen_lista_opciones eb_snap ON eb_snap.id = m.id_estado_balon
        LEFT JOIN gen_almacen au_snap ON au_snap.id = m.id_almacen_ubicacion
        LEFT JOIN cli_clientes cu_snap ON cu_snap.id = m.id_cliente_ubicacion
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        -- Recarga por línea (salida/entrada planta externa): id_documento_ref = bal_movimiento_recarga.id
        LEFT JOIN bal_movimiento_recarga mr
            ON tdr.nombre = 'RECARGA'
           AND tm.nombre IN ('SALIDA_PLANTA_EXTERNA', 'ENTRADA_PLANTA_EXTERNA')
           AND mr.id = m.id_documento_ref
        LEFT JOIN cli_clientes mr_prov ON mr.id_proveedor = mr_prov.id
        LEFT JOIN pro_producto mr_prod ON mr.id_producto = mr_prod.id
        LEFT JOIN gen_lista_opciones mr_tipo ON mr.id_tipo_recarga = mr_tipo.id
        -- Orden de recarga planta (ENTRADA_LLENADO) o vía línea
        LEFT JOIN bal_recarga_planta rp
            ON tdr.nombre = 'RECARGA'
           AND (
                (tm.nombre = 'ENTRADA_LLENADO' AND rp.id = m.id_documento_ref)
                OR (mr.id IS NOT NULL AND rp.id = mr.id_recarga_planta)
           )
        LEFT JOIN cli_clientes rp_prov ON rp.id_proveedor = rp_prov.id
        -- La orden guarda el FK a la GRE de salida; la serie/número puede no estar copiada.
        LEFT JOIN gre_guia_remision rp_gre_salida
            ON rp_gre_salida.id = rp.id_guia_salida
           AND rp_gre_salida.estado = 1
        LEFT JOIN com_comprobante_compra cc ON cc.id = rp.id_comprobante_compra AND cc.estado = 1
        LEFT JOIN cli_clientes cc_prov ON cc.id_proveedor = cc_prov.id
        -- Compra como documento principal del movimiento (entrada con factura vinculada)
        LEFT JOIN com_comprobante_compra cc_doc
            ON tdr.nombre = 'COMPRA'
           AND cc_doc.id = m.id_documento_ref
           AND cc_doc.estado = 1
        LEFT JOIN cli_clientes cc_doc_prov ON cc_doc.id_proveedor = cc_doc_prov.id
        LEFT JOIN bal_recarga_planta rp_compra
            ON tdr.nombre = 'COMPRA'
           AND rp_compra.id_comprobante_compra = m.id_documento_ref
           AND rp_compra.estado = 1
        LEFT JOIN gre_guia_remision rp_compra_gre_salida
            ON rp_compra_gre_salida.id = rp_compra.id_guia_salida
           AND rp_compra_gre_salida.estado = 1
        -- Línea de la orden para este cilindro (enriquece ENTRADA_LLENADO / COMPRA)
        LEFT JOIN bal_recarga_planta_detalle rpd
            ON tm.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
           AND rpd.id_balon = m.id_balon
           AND rpd.estado = 1
           AND (
                (tdr.nombre = 'RECARGA' AND rpd.id_recarga_planta = rp.id)
                OR (tdr.nombre = 'COMPRA' AND rpd.id_recarga_planta = rp_compra.id)
           )
        LEFT JOIN pro_producto rpd_prod ON rpd.id_producto = rpd_prod.id
        LEFT JOIN bal_movimiento_recarga mr_linea
            ON mr_linea.id = rpd.id_movimiento_recarga
           AND mr_linea.estado = 1
        LEFT JOIN cli_clientes mr_linea_prov ON mr_linea.id_proveedor = mr_linea_prov.id
        LEFT JOIN pro_producto mr_linea_prod ON mr_linea.id_producto = mr_linea_prod.id
        LEFT JOIN gen_lista_opciones mr_linea_tipo ON mr_linea.id_tipo_recarga = mr_linea_tipo.id
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
$function$
