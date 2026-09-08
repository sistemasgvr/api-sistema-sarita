-- ============================================================
-- Migración: peso/bultos desde la creación + origen por defecto de la GRE
-- Fecha: 2026-09-07
--
-- 1) doc_crear_salida acepta p_peso_bruto y p_numero_bultos: se piden al crear
--    la orden y la guía de remisión los reutiliza en vez de volver a pedirlos.
--    Los parámetros van AL FINAL de la firma para no romper llamadas
--    posicionales existentes.
--
-- 2) doc_obtener_salida devuelve la ubicación y el ubigeo del almacén
--    (direccion_almacen, id_distrito_almacen, ...) para precargar el punto de
--    partida de la guía.
--
-- 3) doc_actualizar_traslado (nueva): motivo, modalidad, peso y bultos editables
--    sobre la orden. Hasta ahora solo se llenaban al convertir a GRE, y por eso
--    el PDF de una orden que nunca se convertía los imprimía vacíos.
--
-- No cambia ninguna tabla: todas las columnas ya existen en doc_salida.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260907_doc_salida_traslado_y_origen.sql
-- ============================================================



-- ============================================================
-- database_sql/funciones/documentos-salida/doc_crear_salida.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_crear_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
-- p_peso_bruto / p_numero_bultos: se piden al crear la orden y los reutiliza la
-- guía de remisión. Van al final para no romper llamadas posicionales previas.
DROP FUNCTION IF EXISTS doc_crear_salida(p_codigo_tipo_orden character varying, p_id_sucursal integer, p_id_almacen integer, p_id_venta integer, p_id_cliente integer, p_id_destinatario integer, p_id_proveedor integer, p_id_doc_salida_origen integer, p_fecha date, p_fecha_traslado date, p_observaciones character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_crear_salida(p_codigo_tipo_orden character varying, p_id_sucursal integer, p_id_almacen integer, p_id_venta integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_id_doc_salida_origen integer DEFAULT NULL::integer, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_orden INTEGER;
    v_id_borrador INTEGER;
    v_numero VARCHAR;
    v_id INTEGER;
    v_fecha DATE;
    v_id_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);

    SELECT lo.id INTO v_id_tipo_orden
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrdenSalida' AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_orden, ''))) AND lo.estado = 1;

    IF v_id_tipo_orden IS NULL THEN
        RETURN json_build_object('error', format('Tipo de orden %s no configurado', p_codigo_tipo_orden), 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_borrador
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'BORRADOR' AND lo.estado = 1;

    IF p_id_sucursal IS NULL THEN
        RETURN json_build_object('error', 'La sucursal es obligatoria', 'registro', NULL);
    END IF;

    v_id_almacen := p_id_almacen;
    IF v_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen AND id_sucursal = p_id_sucursal AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén no existe o no pertenece a la sucursal indicada', 'registro', NULL);
    END IF;

    IF p_id_venta IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM ven_comprobante WHERE id = p_id_venta AND estado = 1) THEN
            RETURN json_build_object('error', 'La venta indicada no existe o está anulada', 'registro', NULL);
        END IF;

        -- Una venta no debería tener dos órdenes vivas: duplicaría el documento de traslado.
        IF EXISTS (
            SELECT 1 FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = p_id_venta AND d.estado = 1 AND ec.nombre <> 'ANULADA'
        ) THEN
            RETURN json_build_object('error', 'Esta venta ya tiene una orden de salida vigente', 'registro', NULL);
        END IF;
    END IF;

    v_numero := doc_obtener_siguiente_numero(p_id_sucursal, v_fecha);

    INSERT INTO doc_salida (
        numero, id_tipo_orden, id_estado_ciclo, emitido_sunat,
        id_venta, id_doc_salida_origen,
        id_sucursal, id_almacen, id_cliente, id_destinatario, id_proveedor,
        fecha, fecha_traslado, observaciones,
        peso_bruto, numero_bultos,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        v_numero, v_id_tipo_orden, v_id_borrador, FALSE,
        p_id_venta, p_id_doc_salida_origen,
        p_id_sucursal, v_id_almacen,
        COALESCE(p_id_cliente, (SELECT id_cliente FROM ven_comprobante WHERE id = p_id_venta)),
        p_id_destinatario, p_id_proveedor,
        v_fecha, p_fecha_traslado, p_observaciones,
        p_peso_bruto, p_numero_bultos,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN doc_obtener_salida(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_obtener_salida.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_obtener_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
--
-- Actualizada por database_sql/migraciones/20260905_venta_gas_prestamo_garantia_join.sql:
-- con id_venta el detalle une los items de la venta con los cilindros
-- entregados en prestamo (rol ENTREGADO) y descarta las lineas de garantia.
DROP FUNCTION IF EXISTS doc_obtener_salida(p_id integer);

CREATE OR REPLACE FUNCTION doc_obtener_salida(p_id integer)
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
        --              vez de mostrar qué se vendió originalmente.
        --   PRESTAMO — los cilindros entregados en préstamo por esa misma venta.
        --              Van como fila propia aunque la línea de gas ya traiga ese
        --              mismo id_balon: son dos cosas distintas que el cliente se
        --              lleva a la vez (el contenido y el envase), y la orden de
        --              salida tiene que mencionar ambas.
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
                1::NUMERIC AS cantidad,
                NULL::INTEGER AS id_unidad_medida,
                NULL::VARCHAR AS nombre_unidad_medida,
                NULL::VARCHAR AS codigo_unidad_medida,
                tb.nombre::VARCHAR AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'PRESTAMO'::VARCHAR AS origen_detalle
            FROM bal_prestamo pr
            INNER JOIN bal_prestamo_detalle pd
                ON pd.id_prestamo = pr.id AND pd.estado = 1
            LEFT JOIN bal_balon b ON b.id = pd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            WHERE pr.id_comprobante_venta = v_id_venta
              AND pr.estado = 1
              AND pd.rol = 'ENTREGADO'
              AND pd.id_balon IS NOT NULL
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
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
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
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
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
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        LEFT JOIN gen_vehiculo veh ON veh.id = d.id_vehiculo
        LEFT JOIN gen_lista_opciones umd ON umd.id = d.id_unidad_medida
        LEFT JOIN gen_distrito distalm ON distalm.id = alm.id_distrito
        LEFT JOIN gen_departamento depalm ON depalm.id = alm.id_departamento
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
        LEFT JOIN gen_lista_opciones tdch ON tdch.id = cho.id_tipo_documento
        LEFT JOIN gen_lista_opciones tddest ON tddest.id = dest.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdcli ON tdcli.id = cli.id_tipo_documento
        LEFT JOIN auth_usuarios uc ON uc.id = d.id_usuario_creacion
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_actualizar_traslado.sql
-- ============================================================

-- Function: doc_actualizar_traslado
-- Datos de traslado de la orden: motivo, modalidad, peso y bultos.
--
-- Hasta ahora estos campos solo se llenaban en doc_convertir_a_gre, así que una
-- orden de salida que nunca se convierte a guía los tenía siempre en NULL y
-- salían vacíos en el PDF. Esta función los deja editar sobre el documento.
--
-- Se puede editar mientras el documento no esté anulado ni emitido a SUNAT:
-- después de la emisión el contenido es inmutable.
DROP FUNCTION IF EXISTS doc_actualizar_traslado(p_id integer, p_id_motivo_traslado integer, p_id_modalidad_traslado integer, p_peso_bruto numeric, p_numero_bultos integer, p_id_unidad_medida integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_actualizar_traslado(p_id integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_emitido BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ec.nombre, COALESCE(d.emitido_sunat, FALSE)
    INTO v_estado, v_emitido
    FROM doc_salida d
    LEFT JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_estado = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF v_emitido THEN
        RETURN json_build_object(
            'error', 'El documento ya fue emitido a SUNAT: sus datos de traslado no se pueden cambiar',
            'registro', NULL
        );
    END IF;

    IF p_numero_bultos IS NOT NULL AND p_numero_bultos < 0 THEN
        RETURN json_build_object('error', 'El número de bultos no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_peso_bruto IS NOT NULL AND p_peso_bruto < 0 THEN
        RETURN json_build_object('error', 'El peso bruto no puede ser negativo', 'registro', NULL);
    END IF;

    UPDATE doc_salida
    SET id_motivo_traslado    = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_modalidad_traslado = COALESCE(p_id_modalidad_traslado, id_modalidad_traslado),
        peso_bruto            = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos         = COALESCE(p_numero_bultos, numero_bultos),
        id_unidad_medida      = COALESCE(p_id_unidad_medida, id_unidad_medida),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion    = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
