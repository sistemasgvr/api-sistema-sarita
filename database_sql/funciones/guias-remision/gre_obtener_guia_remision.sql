CREATE OR REPLACE FUNCTION gre_obtener_guia_remision(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_referencias JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.id_tipo_guia_remision,
            tg.nombre AS nombre_tipo_guia,
            tg.descripcion AS codigo_tipo_guia,
            g.serie,
            g.numero,
            g.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            g.ticket_sunat,
            g.hash_documento,
            g.fecha,
            g.tipo_cambio,
            g.id_sucursal,
            suc.nombre AS nombre_sucursal,
            g.id_almacen,
            alm.nombre AS nombre_almacen,
            g.id_cliente,
            COALESCE(
                cli.razon_social,
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS nombre_cliente,
            cli.numero_documento AS documento_cliente,
            cli_td.descripcion AS codigo_tipo_doc_cliente,
            cli_td.nombre AS nombre_tipo_doc_cliente,
            g.fecha_traslado,
            g.id_motivo_traslado,
            mt.nombre AS nombre_motivo_traslado,
            mt.descripcion AS codigo_motivo_traslado,
            g.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            um.descripcion AS codigo_unidad_medida,
            g.peso_bruto,
            g.numero_bultos,
            g.direccion_origen,
            g.id_distrito_origen,
            do_orig.nombre AS nombre_distrito_origen,
            do_orig.codigo_ubigeo AS ubigeo_origen,
            do_orig.id_provincia AS id_provincia_origen,
            po_orig.id_departamento AS id_departamento_origen,
            dep_orig.id_pais AS id_pais_origen,
            g.id_destinatario,
            COALESCE(
                dest.razon_social,
                TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno))
            ) AS nombre_destinatario,
            dest.numero_documento AS documento_destinatario,
            td.descripcion AS codigo_tipo_doc_destinatario,
            td.nombre AS nombre_tipo_doc_destinatario,
            g.direccion_llegada,
            g.id_distrito_llegada,
            do_lleg.nombre AS nombre_distrito_llegada,
            do_lleg.codigo_ubigeo AS ubigeo_llegada,
            do_lleg.id_provincia AS id_provincia_llegada,
            po_lleg.id_departamento AS id_departamento_llegada,
            dep_lleg.id_pais AS id_pais_llegada,
            g.id_modalidad_traslado,
            md.nombre AS nombre_modalidad_traslado,
            md.descripcion AS codigo_modalidad_traslado,
            g.id_transportista,
            COALESCE(
                transp.razon_social,
                TRIM(CONCAT_WS(' ', transp.nombres, transp.apellido_paterno, transp.apellido_materno))
            ) AS nombre_transportista,
            transp.numero_documento AS documento_transportista,
            g.id_chofer,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer,
            ch.numero_documento AS documento_chofer,
            ch_td.descripcion AS codigo_tipo_doc_chofer,
            lic.codigo AS licencia_chofer,
            g.id_vehiculo,
            veh.placa AS placa_vehiculo,
            g.id_responsable,
            g.observaciones,
            g.periodo_contable,
            g.operacion,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion
        FROM gre_guia_remision g
        LEFT JOIN gen_lista_opciones tg ON g.id_tipo_guia_remision = tg.id
        LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mt ON g.id_motivo_traslado = mt.id
        LEFT JOIN gen_lista_opciones um ON g.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones md ON g.id_modalidad_traslado = md.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_sucursal suc ON g.id_sucursal = suc.id
        LEFT JOIN gen_almacen alm ON g.id_almacen = alm.id
        LEFT JOIN cli_clientes cli ON g.id_cliente = cli.id
        LEFT JOIN gen_lista_opciones cli_td ON cli.id_tipo_documento = cli_td.id
        LEFT JOIN cli_clientes dest ON g.id_destinatario = dest.id
        LEFT JOIN gen_lista_opciones td ON dest.id_tipo_documento = td.id
        LEFT JOIN cli_clientes transp ON g.id_transportista = transp.id
        LEFT JOIN gen_chofer ch ON g.id_chofer = ch.id
        LEFT JOIN gen_lista_opciones ch_td ON ch.id_tipo_documento = ch_td.id
        LEFT JOIN LATERAL (
            SELECT gl.codigo
            FROM gen_licencia gl
            WHERE gl.id_chofer = ch.id AND gl.estado = 1
            ORDER BY gl.id DESC
            LIMIT 1
        ) lic ON TRUE
        LEFT JOIN gen_vehiculo veh ON g.id_vehiculo = veh.id
        LEFT JOIN gen_distrito do_orig ON g.id_distrito_origen = do_orig.id
        LEFT JOIN gen_provincia po_orig ON do_orig.id_provincia = po_orig.id
        LEFT JOIN gen_departamento dep_orig ON po_orig.id_departamento = dep_orig.id
        LEFT JOIN gen_distrito do_lleg ON g.id_distrito_llegada = do_lleg.id
        LEFT JOIN gen_provincia po_lleg ON do_lleg.id_provincia = po_lleg.id
        LEFT JOIN gen_departamento dep_lleg ON po_lleg.id_departamento = dep_lleg.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Guía de remisión no encontrada');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            det.id,
            det.item,
            det.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            det.descripcion,
            det.id_unidad_medida,
            umd.nombre AS nombre_unidad_medida,
            umd.descripcion AS codigo_unidad_medida,
            det.cantidad,
            det.id_balon,
            bal.codigo_balon AS codigo_balon,
            det.glosa
        FROM gre_guia_remision_detalle det
        LEFT JOIN pro_producto p ON det.id_producto = p.id
        LEFT JOIN gen_lista_opciones umd ON det.id_unidad_medida = umd.id
        LEFT JOIN bal_balon bal ON det.id_balon = bal.id
        WHERE det.id_guia_remision = p_id AND det.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.id), '[]'::JSON)
    INTO v_referencias
    FROM (
        SELECT
            ref.id,
            ref.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            ref.serie,
            ref.numero,
            ref.fecha
        FROM gre_documentos_referencia ref
        LEFT JOIN gen_lista_opciones tc ON ref.id_tipo_comprobante = tc.id
        WHERE ref.id_guia_remision = p_id AND ref.estado = 1
    ) r;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles,
        'referencias', v_referencias
    );
END;
$function$;
