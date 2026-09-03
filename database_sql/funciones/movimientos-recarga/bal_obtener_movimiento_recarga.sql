-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.948Z
DROP FUNCTION IF EXISTS bal_obtener_movimiento_recarga(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_movimiento_recarga(p_id integer)
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
            mr.id,
            mr.fecha_salida_almacen,
            mr.id_balon,
            b.codigo_balon,
            mr.id_balon_origen,
            bo.codigo_balon AS codigo_balon_origen,
            mr.id_comprobante_compra,
            mr.id_cliente,
            cli.razon_social AS nombre_cliente,
            cli.numero_documento AS documento_cliente,
            mr.id_tipo_recarga,
            tr.nombre AS tipo_recarga_nombre,
            tr.descripcion AS tipo_recarga_descripcion,
            mr.id_producto,
            p.nombre AS nombre_producto,
            COALESCE(mr.capacidad, tb.capacidad) AS capacidad,
            mr.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            mr.id_doc_salida,
            rp.numero AS numero_recarga_planta,
            rp.id,
            rp.id_doc_salida_origen,
            -- Guías/factura se resuelven desde la orden de planta y sus FKs;
            -- el texto propio del movimiento manda solo si existe (legacy).
            COALESCE(mr.serie_guia_salida, rp.serie_guia_salida, grs.serie) AS serie_guia_salida,
            COALESCE(mr.numero_guia_salida, rp.numero_guia_salida, grs.numero_sunat) AS numero_guia_salida,
            COALESCE(mr.serie_guia_ingreso, rp.serie_guia_ingreso, gri.serie) AS serie_guia_ingreso,
            COALESCE(mr.numero_guia_ingreso, rp.numero_guia_ingreso, gri.numero_sunat) AS numero_guia_ingreso,
            COALESCE(mr.serie_factura, cc.serie, rp.serie_factura) AS serie_factura,
            COALESCE(mr.numero_factura, cc.numero, rp.numero_factura) AS numero_factura,
            mr.id_comprobante,
            mr.fecha_llegada_almacen,
            mr.lote,
            mr.fecha_vencimiento_lote,
            mr.fecha_prueba_hidrostatica,
            mr.id_proveedor,
            prov.razon_social AS nombre_proveedor,
            mr.observacion,
            mr.id_almacen,
            a.nombre AS nombre_almacen,
            mr.estado,
            mr.fecha_creacion,
            mr.fecha_modificacion,
            mr.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            mr.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM bal_movimiento_recarga mr
        INNER JOIN bal_balon b ON mr.id_balon = b.id
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN bal_balon bo ON mr.id_balon_origen = bo.id
        LEFT JOIN doc_salida rp ON rp.id = mr.id_doc_salida AND rp.estado = 1
        LEFT JOIN doc_salida grs ON grs.id = rp.id AND grs.estado = 1
        LEFT JOIN doc_salida gri ON gri.id = rp.id_doc_salida_origen AND gri.estado = 1
        LEFT JOIN com_comprobante_compra cc ON cc.id = mr.id_comprobante_compra AND cc.estado = 1
        LEFT JOIN cli_clientes cli ON mr.id_cliente = cli.id
        LEFT JOIN gen_lista_opciones tr ON mr.id_tipo_recarga = tr.id
        LEFT JOIN pro_producto p ON mr.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON mr.id_unidad_medida = um.id
        LEFT JOIN cli_clientes prov ON mr.id_proveedor = prov.id
        LEFT JOIN gen_almacen a ON mr.id_almacen = a.id
        LEFT JOIN auth_usuarios uc ON mr.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON mr.id_usuario_modificacion = um2.id
        WHERE mr.id = p_id AND mr.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
