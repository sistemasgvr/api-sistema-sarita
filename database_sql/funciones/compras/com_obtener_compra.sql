DROP FUNCTION IF EXISTS com_obtener_compra;

CREATE OR REPLACE FUNCTION com_obtener_compra(p_id INTEGER)
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
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_proveedor,
            p.razon_social AS razon_social_proveedor,
            p.numero_documento AS doc_proveedor,
            c.id_tipo_registro,
            tr.nombre AS nombre_tipo_registro,
            c.id_categoria_gasto,
            cg.nombre AS nombre_categoria_gasto,
            c.id_sucursal,
            s.nombre AS nombre_sucursal,
            c.id_almacen,
            a.nombre AS nombre_almacen,
            c.id_moneda,
            m.nombre AS nombre_moneda,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            c.sub_total,
            c.igv,
            c.total_importe,
            c.afecta_inventario,
            c.declarar_sunat,
            c.glosa,
            c.id_estado,
            ec.nombre AS nombre_estado,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            (
                SELECT COALESCE(json_agg(row_to_json(d)), '[]'::JSON)
                FROM (
                    SELECT
                        det.id,
                        det.item,
                        det.id_clasificacion_gasto,
                        cg_clasif.grupo,
                        cg_clasif.subgrupo,
                        cg_clasif.sub_subgrupo,
                        det.id_producto,
                        prod.nombre AS nombre_producto,
                        det.descripcion,
                        det.id_unidad_medida,
                        um.nombre AS nombre_unidad_medida,
                        det.cantidad,
                        det.precio_unitario,
                        det.importe,
                        det.id_medio_pago,
                        mp.nombre AS nombre_medio_pago,
                        det.fecha_pago,
                        det.numero_operacion,
                        det.afecta_stock,
                        det.observacion
                    FROM com_comprobante_compra_detalle det
                    LEFT JOIN gen_clasificacion_gasto cg_clasif ON det.id_clasificacion_gasto = cg_clasif.id
                    LEFT JOIN pro_producto prod ON det.id_producto = prod.id
                    LEFT JOIN gen_lista_opciones um ON det.id_unidad_medida = um.id
                    LEFT JOIN gen_lista_opciones mp ON det.id_medio_pago = mp.id
                    WHERE det.id_comprobante = c.id AND det.estado = 1
                    ORDER BY det.item ASC
                ) d
            ) AS detalles
        FROM com_comprobante_compra c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones tr ON c.id_tipo_registro = tr.id
        LEFT JOIN gen_lista_opciones cg ON c.id_categoria_gasto = cg.id
        LEFT JOIN gen_lista_opciones m ON c.id_moneda = m.id
        LEFT JOIN gen_lista_opciones ec ON c.id_estado = ec.id
        LEFT JOIN cli_clientes p ON c.id_proveedor = p.id
        LEFT JOIN gen_sucursal s ON c.id_sucursal = s.id
        LEFT JOIN gen_almacen a ON c.id_almacen = a.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;