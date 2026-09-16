-- La licencia pertenece al chofer; el trabajador aporta sus datos de identidad.
BEGIN;
SET LOCAL lock_timeout = '10s';
CREATE OR REPLACE FUNCTION gen_listar_choferes(p_solo_activos integer DEFAULT NULL::integer, p_buscar character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_chofer ch
    LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
    LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
    WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
      AND (
          p_id_cliente IS NULL
          OR ch.id_cliente = p_id_cliente
          OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
      )
      AND (
          p_buscar = ''
          OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.id_trabajador,
            (ch.id_trabajador IS NOT NULL) AS es_chofer_empresa,
            COALESCE(tr.apellido_paterno, ch.apellido_paterno) AS apellido_paterno,
            COALESCE(tr.apellido_materno, ch.apellido_materno) AS apellido_materno,
            COALESCE(tr.nombres, ch.nombres) AS nombres,
            COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) AS id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            COALESCE(tr.numero_documento, ch.numero_documento) AS numero_documento,
            ch.telefono,
            lic.id AS id_licencia,
            lic.codigo AS codigo_licencia,
            lic.fecha_emision,
            lic.fecha_vencimiento,
            lic.id_tipo_licencia,
            tl.nombre AS nombre_tipo_licencia,
            lic.id_categoria_licencia,
            cl.nombre AS nombre_categoria_licencia,
            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
        LEFT JOIN LATERAL (
            SELECT gl.* FROM gen_licencia gl
            WHERE gl.id_chofer = ch.id AND gl.estado = 1
            ORDER BY gl.fecha_vencimiento DESC, gl.fecha_emision DESC, gl.id DESC
            LIMIT 1
        ) lic ON TRUE
        LEFT JOIN gen_lista_opciones tl ON tl.id = lic.id_tipo_licencia
        LEFT JOIN gen_lista_opciones cl ON cl.id = lic.id_categoria_licencia
        LEFT JOIN gen_lista_opciones td ON COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
          AND (
              p_id_cliente IS NULL
              OR ch.id_cliente = p_id_cliente
              OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
          )
          AND (
              p_buscar = ''
              OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
          )
        ORDER BY COALESCE(tr.nombres, ch.nombres) ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

CREATE OR REPLACE FUNCTION gen_obtener_chofer(p_id integer)
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
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.id_trabajador,
            (ch.id_trabajador IS NOT NULL) AS es_chofer_empresa,
            COALESCE(tr.apellido_paterno, ch.apellido_paterno) AS apellido_paterno,
            COALESCE(tr.apellido_materno, ch.apellido_materno) AS apellido_materno,
            COALESCE(tr.nombres, ch.nombres) AS nombres,
            COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) AS id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            COALESCE(tr.numero_documento, ch.numero_documento) AS numero_documento,
            ch.telefono,

            -- Licencia activa con mayor fecha de vencimiento (igual que listado y GRE)
            lic.id                    AS id_licencia,
            lic.codigo                AS codigo_licencia,
            lic.fecha_emision,
            lic.fecha_vencimiento,
            lic.id_tipo_licencia,
            tl.nombre                 AS nombre_tipo_licencia,
            lic.id_categoria_licencia,
            cl.nombre                 AS nombre_categoria_licencia,

            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
        LEFT JOIN gen_lista_opciones td ON COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id

        LEFT JOIN LATERAL (
            SELECT gl.*
            FROM gen_licencia gl
            WHERE gl.id_chofer = ch.id
              AND gl.estado = 1
            ORDER BY gl.fecha_vencimiento DESC, gl.fecha_emision DESC, gl.id DESC
            LIMIT 1
        ) lic ON TRUE
        LEFT JOIN gen_lista_opciones tl ON lic.id_tipo_licencia = tl.id
        LEFT JOIN gen_lista_opciones cl ON lic.id_categoria_licencia = cl.id

        WHERE ch.id = p_id AND ch.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

CREATE OR REPLACE FUNCTION public.doc_obtener_salida(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_id_venta INTEGER;
    v_venta_anulada BOOLEAN;
    v_detalle JSON;
    v_ultimo_item_venta INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id_venta INTO v_id_venta FROM doc_salida d WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_id_venta IS NOT NULL THEN
        SELECT (vc.estado = 0) INTO v_venta_anulada FROM ven_comprobante vc WHERE vc.id = v_id_venta;

        -- El detalle de una orden ligada a venta se arma por JOIN (principio
        -- "detalle no duplicado") y tiene dos orígenes:
        --   VENTA    — los ítems/productos del comprobante. Si la venta fue
        --              anulada sus líneas quedaron en estado=0
        --              (ven_eliminar_comprobante), así que el OR con
        --              v_venta_anulada evita que el documento se vea vacío en
        --              vez de mostrar qué se vendió originalmente. Cuando el
        --              ítem ya trae id_balon, esa fila representa el cilindro
        --              y el gas despachado.
        --   PRESTAMO — cilindros entregados en préstamo por esa misma venta
        --              que NO aparezcan ya en el detalle de la venta. Si el
        --              gas se vendió ligado al mismo cilindro, repetirlo aquí
        --              duplicaba el balón en la orden de salida.
        -- Se excluyen dos cosas: las líneas de garantía antiguas (garantía es
        -- dinero, no se despacha) y los cilindros de rol GARANTIA, que entran al
        -- almacén en vez de salir.
        -- El item de los cilindros continúa la numeración de la venta, así que
        -- se calcula antes: dentro del UNION no hay forma de mirar el otro lado.
        SELECT COALESCE(MAX(vd.item), 0) INTO v_ultimo_item_venta
        FROM ven_comprobante_detalle vd
        WHERE vd.id_comprobante = v_id_venta
          AND (vd.estado = 1 OR v_venta_anulada)
          AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a';

        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                vd.id,
                vd.item,
                vd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(vd.descripcion, p.nombre) AS descripcion,
                vd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                vd.cantidad,
                vd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                COALESCE(pgb.nombre, p.nombre) AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'VENTA'::VARCHAR AS origen_detalle
            FROM ven_comprobante_detalle vd
            LEFT JOIN pro_producto p ON p.id = vd.id_producto
            LEFT JOIN bal_balon b ON b.id = vd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = vd.id_unidad_medida
            WHERE vd.id_comprobante = v_id_venta
              AND (vd.estado = 1 OR v_venta_anulada)
              AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
            UNION ALL
            SELECT
                pd.id,
                v_ultimo_item_venta + (ROW_NUMBER() OVER (ORDER BY pd.id))::INTEGER AS item,
                NULL::INTEGER AS id_producto,
                b.codigo_balon AS codigo_producto,
                (
                    'Cilindro en préstamo — '
                    || COALESCE(b.codigo_balon, 'sin código')
                    || COALESCE(' (' || tb.nombre || ')', '')
                )::VARCHAR AS descripcion,
                pd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                1::NUMERIC AS cantidad,
                NULL::INTEGER AS id_unidad_medida,
                NULL::VARCHAR AS nombre_unidad_medida,
                NULL::VARCHAR AS codigo_unidad_medida,
                COALESCE(pgb.nombre, tb.nombre)::VARCHAR AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'PRESTAMO'::VARCHAR AS origen_detalle
            FROM bal_prestamo pr
            INNER JOIN bal_prestamo_detalle pd
                ON pd.id_prestamo = pr.id AND pd.estado = 1
            LEFT JOIN bal_balon b ON b.id = pd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            WHERE pr.id_comprobante_venta = v_id_venta
              AND pr.estado = 1
              AND pd.rol = 'ENTREGADO'
              AND pd.id_balon IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM ven_comprobante_detalle vd_bal
                  WHERE vd_bal.id_comprobante = v_id_venta
                    AND vd_bal.id_balon = pd.id_balon
                    AND (vd_bal.estado = 1 OR v_venta_anulada)
                    AND COALESCE(vd_bal.descripcion, '') !~* 'garant[ií]a'
              )
        ) t;
    ELSE
        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                dd.id,
                dd.item,
                dd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(dd.descripcion, p.nombre, b.codigo_balon) AS descripcion,
                dd.id_balon,
                b.codigo_balon,
                -- Tipo y almacén del cilindro: la card del detalle los muestra
                -- igual que el selector, y el detalle no los tenía.
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                -- Capacidad del tipo: en planta externa el editor la suma por
                -- gas para topar cuánto se puede declarar que sale. Sin esto,
                -- al recargar un documento ya guardado no habría con qué
                -- calcular ese tope.
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                -- Gas del cilindro: decide si la orden puede asociarse a una
                -- ficha de lote y protocolo (una ficha cubre un solo gas).
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                dd.cantidad,
                dd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                p.nombre AS nombre_producto,
                dd.glosa,
                dd.id_movimiento,
                'PROPIO'::VARCHAR AS origen_detalle
            FROM doc_salida_detalle dd
            LEFT JOIN pro_producto p ON p.id = dd.id_producto
            LEFT JOIN bal_balon b ON b.id = dd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = dd.id_unidad_medida
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
        ) t;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            d.id, d.numero, d.id_empresa,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.id_doc_salida_origen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            -- Destino del traslado: además de mover el stock, es la dirección
            -- de llegada por defecto de la guía de remisión.
            d.id_almacen_destino,
            almdest.nombre AS nombre_almacen_destino,
            almdest.ubicacion AS direccion_almacen_destino,
            almdest.id_distrito AS id_distrito_almacen_destino,
            almdest.id_provincia AS id_provincia_almacen_destino,
            almdest.id_departamento AS id_departamento_almacen_destino,
            depalmdest.id_pais AS id_pais_almacen_destino,
            -- Ubicación del almacén: es el punto de partida por defecto de la
            -- guía de remisión, para no volver a tipear el origen.
            alm.ubicacion AS direccion_almacen,
            alm.id_distrito AS id_distrito_almacen,
            alm.id_provincia AS id_provincia_almacen,
            alm.id_departamento AS id_departamento_almacen,
            distalm.codigo_ubigeo AS ubigeo_almacen,
            depalm.id_pais AS id_pais_almacen,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_destinatario, d.destinatario_nombre, d.destinatario_documento,
            COALESCE(NULLIF(TRIM(d.destinatario_nombre), ''),
                     NULLIF(TRIM(dest.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno)), '')) AS nombre_destinatario,
            COALESCE(NULLIF(TRIM(d.destinatario_documento), ''), dest.numero_documento) AS documento_destinatario,
            tddest.nombre AS nombre_tipo_doc_destinatario,
            COALESCE(NULLIF(TRIM(d.remitente_documento), ''), cli.numero_documento) AS documento_cliente,
            tdcli.nombre AS nombre_tipo_doc_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            prov.numero_documento AS documento_proveedor,
            d.fecha, d.fecha_traslado, d.fecha_retorno,
            d.id_tipo_guia_remision, tgr.nombre AS nombre_tipo_guia_remision,
            tgr.descripcion AS codigo_tipo_guia,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            d.ticket_sunat, d.hash_documento, d.cdr_respuesta,
            d.tipo_cambio,
            d.id_motivo_traslado, mt.nombre AS nombre_motivo_traslado,
            mt.descripcion AS codigo_motivo_traslado,
            d.id_modalidad_traslado, mod.nombre AS nombre_modalidad_traslado,
            mod.descripcion AS codigo_modalidad_traslado,
            d.id_unidad_medida, umd.nombre AS nombre_unidad_medida,
            umd.descripcion AS codigo_unidad_medida,
            d.peso_bruto, d.numero_bultos,
            d.direccion_origen, d.id_distrito_origen,
            disto.codigo_ubigeo AS ubigeo_origen,
            disto.id_provincia AS id_provincia_origen,
            provo.id_departamento AS id_departamento_origen,
            depo.id_pais AS id_pais_origen,
            d.direccion_llegada, d.id_distrito_llegada,
            distl.codigo_ubigeo AS ubigeo_llegada,
            distl.id_provincia AS id_provincia_llegada,
            provl.id_departamento AS id_departamento_llegada,
            depl.id_pais AS id_pais_llegada,
            d.direccion_entrega, d.referencia_entrega, d.latitud, d.longitud,
            d.id_distrito_entrega, distent.nombre AS nombre_distrito_entrega,
            distent.codigo_ubigeo AS ubigeo_entrega,
            distent.id_provincia AS id_provincia_entrega,
            propent.id_departamento AS id_departamento_entrega,
            depent.id_pais AS id_pais_entrega,
            d.id_direccion_cliente,
            d.id_transportista,
            COALESCE(NULLIF(TRIM(trans.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', trans.nombres, trans.apellido_paterno, trans.apellido_materno)), '')) AS nombre_transportista,
            trans.numero_documento AS documento_transportista,
            d.id_chofer,
            -- Preferir identidad del trabajador vinculado (más actual) para GRE.
            TRIM(CONCAT_WS(
                ' ',
                COALESCE(NULLIF(TRIM(tra.nombres), ''), cho.nombres),
                COALESCE(NULLIF(TRIM(tra.apellido_paterno), ''), cho.apellido_paterno),
                COALESCE(NULLIF(TRIM(tra.apellido_materno), ''), cho.apellido_materno)
            )) AS nombre_chofer,
            COALESCE(NULLIF(TRIM(tra.numero_documento), ''), cho.numero_documento) AS documento_chofer,
            COALESCE(tdtra.descripcion, tdch.descripcion) AS codigo_tipo_doc_chofer,
            (SELECT lic.codigo FROM gen_licencia lic
              WHERE lic.id_chofer = cho.id AND lic.estado = 1
              ORDER BY lic.fecha_vencimiento DESC, lic.fecha_emision DESC, lic.id DESC LIMIT 1) AS licencia_chofer,
            d.id_vehiculo, veh.placa AS placa_vehiculo, veh.placa,
            d.id_responsable, d.remitente_nombre, d.remitente_documento,
            d.id_comprobante_compra,
            d.serie_guia_salida, d.numero_guia_salida,
            d.serie_guia_ingreso, d.numero_guia_ingreso,
            d.serie_factura, d.numero_factura,
            d.fecha_llegada_almacen, d.lote, d.fecha_vencimiento_lote, d.fecha_prueba_hidrostatica,
            d.id_lote_protocolo,
            -- Almacén al que llegaron los cilindros de planta externa. Es otra
            -- cosa que id_almacen (de dónde salieron), que el retorno pisaba.
            d.id_almacen_retorno, almret.nombre AS nombre_almacen_retorno,
            -- Retorno físico: los envases tienen su entrada vigente. Solo con
            -- esto los cilindros están de vuelta y el gas ingresó; la fecha de
            -- llegada por sí sola no mueve inventario.
            EXISTS (
                SELECT 1
                FROM inv_movimiento m
                JOIN doc_salida_detalle ddr ON ddr.id = m.id_documento_detalle
                JOIN gen_lista_opciones tmv ON tmv.id = m.id_tipo_movimiento
                JOIN gen_lista ltmv ON ltmv.id = tmv.id_lista
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND ltmv.nombre = 'TipoMovInvUnificado'
                  AND tmv.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND ddr.id_doc_salida = d.id
                  AND ddr.id_balon IS NOT NULL
                  AND m.id_balon = ddr.id_balon
            ) AS retorno_fisico,
            d.periodo_contable, d.operacion, d.observaciones, d.id_archivo_pdf,
            d.estado, d.fecha_creacion, d.fecha_modificacion,
            d.id_usuario_creacion, uc.nombre AS nombre_usuario_creacion,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            COALESCE(v_venta_anulada, FALSE) AS venta_anulada,
            v_detalle AS detalle,
            (
                SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON)
                FROM (
                    SELECT dr.id, dr.id_tipo_comprobante, tc.nombre AS nombre_tipo_comprobante,
                           tc.descripcion AS codigo_tipo_comprobante,
                           dr.id_comprobante, dr.serie, dr.numero, dr.fecha
                    FROM doc_salida_referencia dr
                    LEFT JOIN gen_lista_opciones tc ON tc.id = dr.id_tipo_comprobante
                    WHERE dr.id_doc_salida = d.id AND dr.estado = 1
                ) r
            ) AS referencias
        FROM doc_salida d
        LEFT JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        LEFT JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN gen_lista_opciones tgr ON tgr.id = d.id_tipo_guia_remision
        LEFT JOIN gen_lista_opciones mt ON mt.id = d.id_motivo_traslado
        LEFT JOIN gen_lista_opciones mod ON mod.id = d.id_modalidad_traslado
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN gen_almacen almret ON almret.id = d.id_almacen_retorno
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        LEFT JOIN gen_vehiculo veh ON veh.id = d.id_vehiculo
        LEFT JOIN gen_lista_opciones umd ON umd.id = d.id_unidad_medida
        LEFT JOIN gen_distrito distalm ON distalm.id = alm.id_distrito
        LEFT JOIN gen_departamento depalm ON depalm.id = alm.id_departamento
        LEFT JOIN gen_departamento depalmdest ON depalmdest.id = almdest.id_departamento
        LEFT JOIN gen_distrito disto ON disto.id = d.id_distrito_origen
        LEFT JOIN gen_provincia provo ON provo.id = disto.id_provincia
        LEFT JOIN gen_departamento depo ON depo.id = provo.id_departamento
        LEFT JOIN gen_distrito distl ON distl.id = d.id_distrito_llegada
        LEFT JOIN gen_provincia provl ON provl.id = distl.id_provincia
        LEFT JOIN gen_departamento depl ON depl.id = provl.id_departamento
        LEFT JOIN gen_distrito distent ON distent.id = d.id_distrito_entrega
        LEFT JOIN gen_provincia propent ON propent.id = distent.id_provincia
        LEFT JOIN gen_departamento depent ON depent.id = propent.id_departamento
        LEFT JOIN cli_clientes trans ON trans.id = d.id_transportista
        LEFT JOIN cli_clientes dest ON dest.id = d.id_destinatario
        LEFT JOIN gen_chofer cho ON cho.id = d.id_chofer
        LEFT JOIN tra_trabajadores tra ON tra.id = cho.id_trabajador AND tra.estado = 1
        LEFT JOIN gen_lista_opciones tdch ON tdch.id = cho.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdtra ON tdtra.id = tra.id_tipo_documento
        LEFT JOIN gen_lista_opciones tddest ON tddest.id = dest.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdcli ON tdcli.id = cli.id_tipo_documento
        LEFT JOIN auth_usuarios uc ON uc.id = d.id_usuario_creacion
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

COMMIT;
