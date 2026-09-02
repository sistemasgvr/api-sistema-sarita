CREATE OR REPLACE FUNCTION bal_obtener_recarga_planta(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSONB;
    v_detalles JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT to_jsonb(t)
    INTO v_registro
    FROM (
        SELECT
            rp.id,
            rp.numero,
            rp.fecha_salida,
            rp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(prv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', prv.nombres, prv.apellido_paterno)), ''),
                prv.numero_documento
            ) AS nombre_proveedor,
            rp.id_almacen,
            a.nombre AS nombre_almacen,
            rp.id_guia_salida,
            -- Serie/número se resuelven desde el documento vinculado; el texto
            -- guardado solo aplica a órdenes sin FK (guías fuera del sistema).
            COALESCE(rp.serie_guia_salida, gs.serie) AS serie_guia_salida,
            COALESCE(rp.numero_guia_salida, gs.numero) AS numero_guia_salida,
            rp.id_guia_retorno,
            COALESCE(rp.serie_guia_ingreso, gi.serie) AS serie_guia_ingreso,
            COALESCE(rp.numero_guia_ingreso, gi.numero) AS numero_guia_ingreso,
            rp.id_comprobante_compra,
            COALESCE(rp.serie_factura, cc.serie) AS serie_factura,
            COALESCE(rp.numero_factura, cc.numero) AS numero_factura,
            rp.fecha_llegada_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
            rp.fecha_prueba_hidrostatica,
            rp.id_estado,
            est.nombre AS nombre_estado,
            est.descripcion AS descripcion_estado,
            rp.observacion,
            rp.estado,
            rp.fecha_creacion,
            rp.fecha_modificacion
        FROM bal_recarga_planta rp
        LEFT JOIN cli_clientes prv ON prv.id = rp.id_proveedor
        LEFT JOIN gen_almacen a ON a.id = rp.id_almacen
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
        LEFT JOIN gre_guia_remision gs ON gs.id = rp.id_guia_salida AND gs.estado = 1
        LEFT JOIN gre_guia_remision gi ON gi.id = rp.id_guia_retorno AND gi.estado = 1
        LEFT JOIN com_comprobante_compra cc ON cc.id = rp.id_comprobante_compra AND cc.estado = 1
        WHERE rp.id = p_id AND rp.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Orden de recarga no encontrada', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            det.id,
            det.id_recarga_planta,
            det.id_balon,
            b.codigo_balon,
            det.id_producto,
            p.nombre AS nombre_producto,
            p.codigo AS codigo_producto,
            COALESCE(det.capacidad, tb.capacidad) AS capacidad,
            det.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            det.lote,
            det.fecha_vencimiento_lote,
            det.fecha_prueba_hidrostatica,
            det.id_movimiento_recarga,
            det.observacion,
            eb.nombre AS nombre_estado_balon,
            det.estado
        FROM bal_recarga_planta_detalle det
        INNER JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN pro_producto p ON p.id = det.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = det.id_unidad_medida
        WHERE det.id_recarga_planta = p_id AND det.estado = 1
    ) d;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro || jsonb_build_object('detalles', COALESCE(v_detalles::JSONB, '[]'::JSONB)))::JSON
    );
END;
$function$;
