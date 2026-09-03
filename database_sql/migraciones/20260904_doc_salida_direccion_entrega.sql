-- Fase 2 — dirección de entrega y geolocalización para doc_salida.
--
-- Hoy `doc_salida` solo tiene direccion_llegada/id_distrito_llegada, que son
-- parte del "Bloque GRE" y se llenan recién al convertir el documento en
-- guía de remisión (doc_convertir_a_gre). Falta poder capturar la dirección
-- de entrega ANTES de eso — apenas se genera la orden desde una venta — con
-- coordenadas GPS para el mapa. Se agregan columnas dedicadas en vez de
-- reutilizar direccion_llegada/id_distrito_llegada para no mezclar "dónde
-- entrega el pedido" (dato operativo, capturado temprano) con el bloque
-- SUNAT (que se llena después y solo si el documento se convierte en GRE).
--
-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js
-- cuando el usuario lo confirme.

-- 1) Columnas nuevas en doc_salida
ALTER TABLE doc_salida
    ADD COLUMN IF NOT EXISTS direccion_entrega character varying(255),
    ADD COLUMN IF NOT EXISTS referencia_entrega character varying(300),
    ADD COLUMN IF NOT EXISTS latitud numeric(10,7),
    ADD COLUMN IF NOT EXISTS longitud numeric(10,7),
    ADD COLUMN IF NOT EXISTS id_distrito_entrega integer,
    ADD COLUMN IF NOT EXISTS id_direccion_cliente integer;

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_distrito_entrega_fkey
    FOREIGN KEY (id_distrito_entrega) REFERENCES public.gen_distrito(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_direccion_cliente_fkey
    FOREIGN KEY (id_direccion_cliente) REFERENCES public.cli_direcciones(id);

-- 2) ===== database_sql/funciones/documentos-salida/doc_obtener_salida.sql =====
-- (agrega direccion_entrega/referencia_entrega/latitud/longitud/id_distrito_entrega/
-- nombre_distrito_entrega/ubigeo_entrega/id_direccion_cliente al registro)
DROP FUNCTION IF EXISTS doc_obtener_salida(p_id integer);

CREATE OR REPLACE FUNCTION doc_obtener_salida(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_id_venta INTEGER;
    v_detalle JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id_venta INTO v_id_venta FROM doc_salida d WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_id_venta IS NOT NULL THEN
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
                vd.cantidad,
                vd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                p.nombre AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'VENTA'::VARCHAR AS origen_detalle
            FROM ven_comprobante_detalle vd
            LEFT JOIN pro_producto p ON p.id = vd.id_producto
            LEFT JOIN bal_balon b ON b.id = vd.id_balon
            LEFT JOIN gen_lista_opciones um ON um.id = vd.id_unidad_medida
            WHERE vd.id_comprobante = v_id_venta AND vd.estado = 1
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
            LEFT JOIN gen_lista_opciones um ON um.id = dd.id_unidad_medida
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
        ) t;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            d.id, d.numero,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.id_doc_salida_origen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
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
            d.direccion_llegada, d.id_distrito_llegada,
            distl.codigo_ubigeo AS ubigeo_llegada,
            d.direccion_entrega, d.referencia_entrega, d.latitud, d.longitud,
            d.id_distrito_entrega, distent.nombre AS nombre_distrito_entrega,
            distent.codigo_ubigeo AS ubigeo_entrega,
            d.id_direccion_cliente,
            d.id_transportista,
            COALESCE(NULLIF(TRIM(trans.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', trans.nombres, trans.apellido_paterno, trans.apellido_materno)), '')) AS nombre_transportista,
            trans.numero_documento AS documento_transportista,
            d.id_chofer,
            TRIM(CONCAT_WS(' ', cho.nombres, cho.apellido_paterno, cho.apellido_materno)) AS nombre_chofer,
            cho.numero_documento AS documento_chofer,
            tdch.descripcion AS codigo_tipo_doc_chofer,
            (SELECT lic.codigo FROM gen_licencia lic
              WHERE lic.id_chofer = cho.id AND lic.estado = 1
              ORDER BY lic.fecha_vencimiento DESC LIMIT 1) AS licencia_chofer,
            d.id_vehiculo, veh.placa AS placa_vehiculo, veh.placa,
            d.id_responsable, d.remitente_nombre, d.remitente_documento,
            d.id_comprobante_compra,
            d.serie_guia_salida, d.numero_guia_salida,
            d.serie_guia_ingreso, d.numero_guia_ingreso,
            d.serie_factura, d.numero_factura,
            d.fecha_llegada_almacen, d.lote, d.fecha_vencimiento_lote, d.fecha_prueba_hidrostatica,
            d.periodo_contable, d.operacion, d.observaciones, d.id_archivo_pdf,
            d.estado, d.fecha_creacion, d.fecha_modificacion,
            d.id_usuario_creacion, uc.nombre AS nombre_usuario_creacion,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
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
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        LEFT JOIN gen_vehiculo veh ON veh.id = d.id_vehiculo
        LEFT JOIN gen_lista_opciones umd ON umd.id = d.id_unidad_medida
        LEFT JOIN gen_distrito disto ON disto.id = d.id_distrito_origen
        LEFT JOIN gen_distrito distl ON distl.id = d.id_distrito_llegada
        LEFT JOIN gen_distrito distent ON distent.id = d.id_distrito_entrega
        LEFT JOIN cli_clientes trans ON trans.id = d.id_transportista
        LEFT JOIN cli_clientes dest ON dest.id = d.id_destinatario
        LEFT JOIN gen_chofer cho ON cho.id = d.id_chofer
        LEFT JOIN gen_lista_opciones tdch ON tdch.id = cho.id_tipo_documento
        LEFT JOIN gen_lista_opciones tddest ON tddest.id = dest.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdcli ON tdcli.id = cli.id_tipo_documento
        LEFT JOIN auth_usuarios uc ON uc.id = d.id_usuario_creacion
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- 3) ===== database_sql/funciones/documentos-salida/doc_registrar_direccion_entrega.sql =====
-- Registra o actualiza la dirección de entrega + coordenadas de un documento
-- de salida. Se puede llamar en cualquier momento del ciclo (BORRADOR o
-- GENERADA) — no mueve inventario ni cambia estado, solo guarda dónde
-- entregar. Si viene de una dirección guardada del cliente (p_id_direccion_cliente),
-- se copia el snapshot de esa fila; si es manual, se usan los parámetros tal cual.
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_registrar_direccion_entrega(
    p_id integer,
    p_direccion_entrega character varying DEFAULT NULL::character varying,
    p_referencia_entrega character varying DEFAULT NULL::character varying,
    p_latitud numeric DEFAULT NULL::numeric,
    p_longitud numeric DEFAULT NULL::numeric,
    p_id_distrito_entrega integer DEFAULT NULL::integer,
    p_id_direccion_cliente integer DEFAULT NULL::integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_direccion VARCHAR;
    v_referencia VARCHAR;
    v_latitud NUMERIC;
    v_longitud NUMERIC;
    v_id_distrito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF p_id_direccion_cliente IS NOT NULL THEN
        SELECT cd.direccion, cd.referencia, cd.latitud, cd.longitud, cd.id_distrito
        INTO v_direccion, v_referencia, v_latitud, v_longitud, v_id_distrito
        FROM cli_direcciones cd
        WHERE cd.id = p_id_direccion_cliente AND cd.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La dirección del cliente indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    ELSE
        v_direccion := p_direccion_entrega;
        v_referencia := p_referencia_entrega;
        v_latitud := p_latitud;
        v_longitud := p_longitud;
        v_id_distrito := p_id_distrito_entrega;
    END IF;

    IF COALESCE(TRIM(v_direccion), '') = '' THEN
        RETURN json_build_object('error', 'La dirección de entrega es obligatoria', 'registro', NULL);
    END IF;

    UPDATE doc_salida
    SET direccion_entrega = v_direccion,
        referencia_entrega = v_referencia,
        latitud = v_latitud,
        longitud = v_longitud,
        id_distrito_entrega = v_id_distrito,
        id_direccion_cliente = p_id_direccion_cliente,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
