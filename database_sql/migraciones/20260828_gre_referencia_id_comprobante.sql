-- H1: vínculo real (FK) entre las referencias de una GRE y el comprobante de venta.
-- serie / numero / fecha / id_tipo_comprobante se conservan como snapshot fiscal: no se tocan.

ALTER TABLE gre_documentos_referencia
    ADD COLUMN IF NOT EXISTS id_comprobante INT REFERENCES ven_comprobante(id);

CREATE INDEX IF NOT EXISTS idx_gre_doc_ref_comprobante
    ON gre_documentos_referencia(id_comprobante);

-- Backfill: solo cuando tipo + serie + numero identifican un CPE vigente sin ambigüedad
UPDATE gre_documentos_referencia ref
SET id_comprobante = c.id
FROM ven_comprobante c
WHERE ref.id_comprobante IS NULL
  AND c.estado = 1
  AND c.id_tipo_comprobante = ref.id_tipo_comprobante
  AND UPPER(TRIM(COALESCE(c.serie, ''))) = UPPER(TRIM(COALESCE(ref.serie, '')))
  AND TRIM(COALESCE(c.numero, '')) = TRIM(COALESCE(ref.numero, ''))
  AND NULLIF(TRIM(COALESCE(ref.serie, '')), '') IS NOT NULL
  AND NULLIF(TRIM(COALESCE(ref.numero, '')), '') IS NOT NULL;

-- ============================================================
-- Funciones afectadas (mismas firmas, solo cambia el cuerpo)
-- ============================================================

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
                NULLIF(TRIM(g.remitente_nombre), ''),
                cli.razon_social,
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS nombre_cliente,
            COALESCE(
                NULLIF(TRIM(g.remitente_documento), ''),
                cli.numero_documento
            ) AS documento_cliente,
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
                NULLIF(TRIM(g.destinatario_nombre), ''),
                dest.razon_social,
                TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno))
            ) AS nombre_destinatario,
            COALESCE(
                NULLIF(TRIM(g.destinatario_documento), ''),
                dest.numero_documento
            ) AS documento_destinatario,
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
            COALESCE(det.id_unidad_medida, tb.id_unidad_medida) AS id_unidad_medida,
            COALESCE(umd.nombre, umt.nombre) AS nombre_unidad_medida,
            COALESCE(umd.descripcion, umt.descripcion) AS codigo_unidad_medida,
            det.cantidad,
            det.id_balon,
            bal.codigo_balon AS codigo_balon,
            tb.capacidad AS capacidad_tipo_balon,
            tb.capacidad AS capacidad,
            eb.nombre AS nombre_estado_balon,
            ec.nombre AS nombre_estado_contenido,
            det.glosa
        FROM gre_guia_remision_detalle det
        LEFT JOIN pro_producto p ON det.id_producto = p.id
        LEFT JOIN gen_lista_opciones umd ON det.id_unidad_medida = umd.id
        LEFT JOIN bal_balon bal ON det.id_balon = bal.id
        LEFT JOIN bal_tipo_balon tb ON tb.id = bal.id_tipo_balon
        LEFT JOIN gen_lista_opciones umt ON umt.id = tb.id_unidad_medida
        LEFT JOIN gen_lista_opciones eb ON eb.id = bal.id_estado_balon
        LEFT JOIN gen_lista_opciones ec ON ec.id = bal.id_estado_contenido
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
            ref.id_comprobante,
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

CREATE OR REPLACE FUNCTION gre_crear_guia_remision(
    p_id_tipo_guia_remision INTEGER,
    p_serie VARCHAR,
    p_numero VARCHAR DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_fecha_traslado DATE DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_motivo_traslado INTEGER DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_peso_bruto NUMERIC DEFAULT NULL,
    p_numero_bultos INTEGER DEFAULT NULL,
    p_direccion_origen VARCHAR DEFAULT NULL,
    p_id_distrito_origen INTEGER DEFAULT NULL,
    p_id_destinatario INTEGER DEFAULT NULL,
    p_destinatario_nombre VARCHAR DEFAULT NULL,
    p_destinatario_documento VARCHAR DEFAULT NULL,
    p_direccion_llegada VARCHAR DEFAULT NULL,
    p_id_distrito_llegada INTEGER DEFAULT NULL,
    p_id_modalidad_traslado INTEGER DEFAULT NULL,
    p_id_transportista INTEGER DEFAULT NULL,
    p_id_chofer INTEGER DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL,
    p_id_responsable INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]'::JSON,
    p_referencias JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_remitente_nombre VARCHAR DEFAULT NULL,
    p_remitente_documento VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_serie VARCHAR(10);
    v_numero VARCHAR(15);
    v_fecha DATE;
    v_fecha_traslado DATE;
    v_id_estado_sunat INTEGER;
    v_id_estado INTEGER;
    v_codigo_tipo VARCHAR;
    v_codigo_modalidad VARCHAR;
    v_detalle JSON;
    v_ref JSON;
    v_item INTEGER := 0;
    v_salidas JSON;
    v_destinatario_nombre VARCHAR(255);
    v_destinatario_documento VARCHAR(20);
    v_id_destinatario INTEGER;
    v_remitente_nombre VARCHAR(255);
    v_remitente_documento VARCHAR(20);
    v_id_cliente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_fecha_traslado := COALESCE(p_fecha_traslado, v_fecha);
    v_destinatario_nombre := NULLIF(TRIM(p_destinatario_nombre), '');
    v_destinatario_documento := NULLIF(TRIM(p_destinatario_documento), '');
    -- Nombre libre tiene prioridad: no amarra FK de cliente
    v_id_destinatario := CASE
        WHEN v_destinatario_nombre IS NOT NULL THEN NULL
        ELSE p_id_destinatario
    END;
    v_remitente_nombre := NULLIF(TRIM(p_remitente_nombre), '');
    v_remitente_documento := NULLIF(TRIM(p_remitente_documento), '');
    v_id_cliente := CASE
        WHEN v_remitente_nombre IS NOT NULL THEN NULL
        ELSE p_id_cliente
    END;

    IF p_id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guía es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NULL OR p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'Sucursal y almacén son obligatorios', 'registro', NULL);
    END IF;

    IF v_id_destinatario IS NULL AND (v_destinatario_nombre IS NULL OR v_destinatario_documento IS NULL) THEN
        RETURN json_build_object(
            'error',
            'El destinatario es obligatorio: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    IF p_id_motivo_traslado IS NULL OR p_id_modalidad_traslado IS NULL THEN
        RETURN json_build_object('error', 'Motivo y modalidad de traslado son obligatorios', 'registro', NULL);
    END IF;

    IF p_id_distrito_origen IS NULL OR p_id_distrito_llegada IS NULL THEN
        RETURN json_build_object('error', 'Distrito de origen y llegada son obligatorios (ubigeo SUNAT)', 'registro', NULL);
    END IF;

    IF COALESCE(p_peso_bruto, 0) <= 0 THEN
        RETURN json_build_object('error', 'El peso bruto debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un ítem', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_guia_remision AND lo.estado = 1;

    IF v_codigo_tipo IS NULL THEN
        RETURN json_build_object('error', 'Tipo de guía inválido', 'registro', NULL);
    END IF;

    -- Serie GRE remitente inicia con T; transportista con V (convención SUNAT)
    IF v_codigo_tipo = '09' AND LEFT(v_serie, 1) <> 'T' THEN
        RETURN json_build_object('error', 'La serie de GRE remitente (09) debe iniciar con T (ej. T001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '31' AND LEFT(v_serie, 1) <> 'V' THEN
        RETURN json_build_object('error', 'La serie de GRE transportista (31) debe iniciar con V (ej. V001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '31'
       AND v_id_cliente IS NULL
       AND (v_remitente_nombre IS NULL OR v_remitente_documento IS NULL)
    THEN
        RETURN json_build_object(
            'error',
            'El remitente es obligatorio en GRE transportista: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.descripcion INTO v_codigo_modalidad
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_modalidad_traslado AND lo.estado = 1;

    IF v_codigo_modalidad = '02' AND (p_id_chofer IS NULL OR p_id_vehiculo IS NULL) THEN
        RETURN json_build_object('error', 'Transporte privado requiere chofer y vehículo', 'registro', NULL);
    END IF;

    IF v_codigo_modalidad = '01' AND p_id_transportista IS NULL THEN
        RETURN json_build_object('error', 'Transporte público requiere transportista', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGuiaRemision' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF p_numero IS NULL OR TRIM(p_numero) = '' THEN
        SELECT (gre_obtener_siguiente_numero(v_serie)->>'numero') INTO v_numero;
    ELSE
        v_numero := LPAD(REGEXP_REPLACE(TRIM(p_numero), '[^0-9]', '', 'g'), 8, '0');
    END IF;

    IF EXISTS (
        SELECT 1 FROM gre_guia_remision
        WHERE estado = 1 AND UPPER(serie) = v_serie AND numero = v_numero
    ) THEN
        RETURN json_build_object('error', 'Ya existe una guía con esa serie y número', 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO gre_guia_remision (
            id_tipo_guia_remision, serie, numero, id_estado_sunat,
            fecha, tipo_cambio, id_sucursal, id_almacen, id_cliente,
            remitente_nombre, remitente_documento,
            fecha_traslado, id_motivo_traslado, id_unidad_medida,
            peso_bruto, numero_bultos,
            direccion_origen, id_distrito_origen,
            id_destinatario, destinatario_nombre, destinatario_documento,
            direccion_llegada, id_distrito_llegada,
            id_modalidad_traslado, id_transportista, id_chofer, id_vehiculo,
            id_responsable, observaciones, id_estado,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            p_id_tipo_guia_remision, v_serie, v_numero, v_id_estado_sunat,
            v_fecha, 3.5, p_id_sucursal, p_id_almacen, v_id_cliente,
            v_remitente_nombre, v_remitente_documento,
            v_fecha_traslado, p_id_motivo_traslado, p_id_unidad_medida,
            p_peso_bruto, COALESCE(p_numero_bultos, 1),
            NULLIF(TRIM(p_direccion_origen), ''), p_id_distrito_origen,
            v_id_destinatario, v_destinatario_nombre, v_destinatario_documento,
            NULLIF(TRIM(p_direccion_llegada), ''), p_id_distrito_llegada,
            p_id_modalidad_traslado, p_id_transportista, p_id_chofer, p_id_vehiculo,
            p_id_responsable, NULLIF(TRIM(p_observaciones), ''), v_id_estado,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe una guía con esa serie y número', 'registro', NULL);
    END;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        IF (v_detalle->>'idProducto') IS NULL
           AND (v_detalle->>'id_producto') IS NULL
           AND (v_detalle->>'idBalon') IS NULL
           AND (v_detalle->>'id_balon') IS NULL
           AND NULLIF(TRIM(COALESCE(v_detalle->>'glosa', v_detalle->>'descripcion', '')), '') IS NULL
        THEN
            RETURN json_build_object(
                'error',
                format('Ítem %s: indica cilindro, producto o descripción', v_item),
                'registro',
                NULL
            );
        END IF;

        IF COALESCE((v_detalle->>'cantidad')::NUMERIC, 0) <= 0 THEN
            RETURN json_build_object('error', format('Ítem %s: cantidad inválida', v_item), 'registro', NULL);
        END IF;

        INSERT INTO gre_guia_remision_detalle (
            id_guia_remision, item, id_producto, descripcion,
            id_unidad_medida, cantidad, id_balon, glosa,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id,
            COALESCE((v_detalle->>'item')::INTEGER, v_item),
            COALESCE((v_detalle->>'idProducto')::INTEGER, (v_detalle->>'id_producto')::INTEGER),
            NULLIF(TRIM(COALESCE(v_detalle->>'descripcion', '')), ''),
            COALESCE((v_detalle->>'idUnidadMedida')::INTEGER, (v_detalle->>'id_unidad_medida')::INTEGER),
            (v_detalle->>'cantidad')::NUMERIC,
            COALESCE((v_detalle->>'idBalon')::INTEGER, (v_detalle->>'id_balon')::INTEGER),
            NULLIF(TRIM(COALESCE(v_detalle->>'glosa', '')), ''),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    IF p_referencias IS NOT NULL AND json_typeof(p_referencias) = 'array' THEN
        FOR v_ref IN SELECT value FROM json_array_elements(p_referencias)
        LOOP
            INSERT INTO gre_documentos_referencia (
                id_guia_remision, id_tipo_comprobante, id_comprobante, serie, numero, fecha,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                COALESCE((v_ref->>'idTipoComprobante')::INTEGER, (v_ref->>'id_tipo_comprobante')::INTEGER),
                COALESCE((v_ref->>'idComprobante')::INTEGER, (v_ref->>'id_comprobante')::INTEGER),
                NULLIF(UPPER(TRIM(COALESCE(v_ref->>'serie', ''))), ''),
                NULLIF(TRIM(COALESCE(v_ref->>'numero', '')), ''),
                NULLIF(v_ref->>'fecha', '')::DATE,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- CY1: salida automática de cilindros con código en la GRE
    v_salidas := bal_aplicar_salidas_guia_remision(v_id, p_id_usuario_auditoria);
    IF v_salidas->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_salidas->>'error';
    END IF;

    RETURN gre_obtener_guia_remision(v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION gre_actualizar_guia_remision(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_fecha_traslado DATE DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_motivo_traslado INTEGER DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_peso_bruto NUMERIC DEFAULT NULL,
    p_numero_bultos INTEGER DEFAULT NULL,
    p_direccion_origen VARCHAR DEFAULT NULL,
    p_id_distrito_origen INTEGER DEFAULT NULL,
    p_id_destinatario INTEGER DEFAULT NULL,
    p_destinatario_nombre VARCHAR DEFAULT NULL,
    p_destinatario_documento VARCHAR DEFAULT NULL,
    p_direccion_llegada VARCHAR DEFAULT NULL,
    p_id_distrito_llegada INTEGER DEFAULT NULL,
    p_id_modalidad_traslado INTEGER DEFAULT NULL,
    p_id_transportista INTEGER DEFAULT NULL,
    p_id_chofer INTEGER DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL,
    p_id_responsable INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT NULL,
    p_referencias JSON DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_remitente_nombre VARCHAR DEFAULT NULL,
    p_remitente_documento VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_codigo_modalidad VARCHAR;
    v_codigo_tipo VARCHAR;
    v_id_tipo INTEGER;
    v_id_modalidad INTEGER;
    v_id_destinatario INTEGER;
    v_destinatario_nombre VARCHAR(255);
    v_destinatario_documento VARCHAR(20);
    v_id_cliente INTEGER;
    v_remitente_nombre VARCHAR(255);
    v_remitente_documento VARCHAR(20);
    v_id_distrito_origen INTEGER;
    v_id_distrito_llegada INTEGER;
    v_peso NUMERIC;
    v_detalle JSON;
    v_ref JSON;
    v_item INTEGER := 0;
    v_salidas JSON;
    v_ids_conservar INTEGER[] := ARRAY[]::INTEGER[];
    v_id_balon_linea INTEGER;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, g.id_tipo_guia_remision
    INTO v_estado_sunat, v_id_tipo
    FROM gre_guia_remision g
    LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
    WHERE g.id = p_id AND g.estado = 1;

    IF v_estado_sunat IS NULL AND v_id_tipo IS NULL THEN
        RETURN json_build_object('error', 'Guía de remisión no encontrada', 'registro', NULL);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'error', 'No se puede editar una guía aceptada por SUNAT',
            'registro', NULL
        );
    END IF;

    SELECT
        COALESCE(p_id_modalidad_traslado, g.id_modalidad_traslado),
        CASE
            WHEN p_destinatario_nombre IS NOT NULL
                 AND NULLIF(TRIM(p_destinatario_nombre), '') IS NOT NULL THEN NULL
            WHEN p_id_destinatario IS NOT NULL THEN p_id_destinatario
            ELSE g.id_destinatario
        END,
        CASE
            WHEN p_id_destinatario IS NOT NULL THEN NULL
            WHEN p_destinatario_nombre IS NOT NULL THEN NULLIF(TRIM(p_destinatario_nombre), '')
            ELSE NULLIF(TRIM(g.destinatario_nombre), '')
        END,
        CASE
            WHEN p_id_destinatario IS NOT NULL THEN NULL
            WHEN p_destinatario_documento IS NOT NULL THEN NULLIF(TRIM(p_destinatario_documento), '')
            ELSE NULLIF(TRIM(g.destinatario_documento), '')
        END,
        CASE
            WHEN p_remitente_nombre IS NOT NULL
                 AND NULLIF(TRIM(p_remitente_nombre), '') IS NOT NULL THEN NULL
            WHEN p_id_cliente IS NOT NULL THEN p_id_cliente
            ELSE g.id_cliente
        END,
        CASE
            WHEN p_id_cliente IS NOT NULL THEN NULL
            WHEN p_remitente_nombre IS NOT NULL THEN NULLIF(TRIM(p_remitente_nombre), '')
            ELSE NULLIF(TRIM(g.remitente_nombre), '')
        END,
        CASE
            WHEN p_id_cliente IS NOT NULL THEN NULL
            WHEN p_remitente_documento IS NOT NULL THEN NULLIF(TRIM(p_remitente_documento), '')
            ELSE NULLIF(TRIM(g.remitente_documento), '')
        END,
        COALESCE(p_id_distrito_origen, g.id_distrito_origen),
        COALESCE(p_id_distrito_llegada, g.id_distrito_llegada),
        COALESCE(p_peso_bruto, g.peso_bruto)
    INTO
        v_id_modalidad,
        v_id_destinatario,
        v_destinatario_nombre,
        v_destinatario_documento,
        v_id_cliente,
        v_remitente_nombre,
        v_remitente_documento,
        v_id_distrito_origen,
        v_id_distrito_llegada,
        v_peso
    FROM gre_guia_remision g
    WHERE g.id = p_id AND g.estado = 1;

    IF v_id_destinatario IS NULL
       AND (v_destinatario_nombre IS NULL OR v_destinatario_documento IS NULL)
    THEN
        RETURN json_build_object(
            'error',
            'El destinatario es obligatorio: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = v_id_tipo AND lo.estado = 1;

    IF v_codigo_tipo = '31'
       AND v_id_cliente IS NULL
       AND (v_remitente_nombre IS NULL OR v_remitente_documento IS NULL)
    THEN
        RETURN json_build_object(
            'error',
            'El remitente es obligatorio en GRE transportista: selecciona un cliente o ingresa nombre y documento',
            'registro',
            NULL
        );
    END IF;

    IF v_id_distrito_origen IS NULL OR v_id_distrito_llegada IS NULL THEN
        RETURN json_build_object('error', 'Distrito de origen y llegada son obligatorios (ubigeo SUNAT)', 'registro', NULL);
    END IF;

    IF COALESCE(v_peso, 0) <= 0 THEN
        RETURN json_build_object('error', 'El peso bruto debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_modalidad
    FROM gen_lista_opciones lo
    WHERE lo.id = v_id_modalidad AND lo.estado = 1;

    IF v_codigo_modalidad = '02'
       AND (
           COALESCE(p_id_chofer, (SELECT id_chofer FROM gre_guia_remision WHERE id = p_id)) IS NULL
           OR COALESCE(p_id_vehiculo, (SELECT id_vehiculo FROM gre_guia_remision WHERE id = p_id)) IS NULL
       )
    THEN
        RETURN json_build_object('error', 'Transporte privado requiere chofer y vehículo', 'registro', NULL);
    END IF;

    IF v_codigo_modalidad = '01'
       AND COALESCE(p_id_transportista, (SELECT id_transportista FROM gre_guia_remision WHERE id = p_id)) IS NULL
    THEN
        RETURN json_build_object('error', 'Transporte público requiere transportista', 'registro', NULL);
    END IF;

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un ítem', 'registro', NULL);
        END IF;
    END IF;

    UPDATE gre_guia_remision
    SET
        fecha = COALESCE(p_fecha, fecha),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_cliente = v_id_cliente,
        remitente_nombre = v_remitente_nombre,
        remitente_documento = v_remitente_documento,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(NULLIF(TRIM(p_direccion_origen), ''), direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        id_destinatario = v_id_destinatario,
        destinatario_nombre = v_destinatario_nombre,
        destinatario_documento = v_destinatario_documento,
        direccion_llegada = COALESCE(NULLIF(TRIM(p_direccion_llegada), ''), direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        id_modalidad_traslado = COALESCE(p_id_modalidad_traslado, id_modalidad_traslado),
        id_transportista = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '02' THEN NULL
            ELSE COALESCE(p_id_transportista, id_transportista)
        END,
        id_chofer = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '01' THEN NULL
            ELSE COALESCE(p_id_chofer, id_chofer)
        END,
        id_vehiculo = CASE
            WHEN p_id_modalidad_traslado IS NOT NULL AND v_codigo_modalidad = '01' THEN NULL
            ELSE COALESCE(p_id_vehiculo, id_vehiculo)
        END,
        id_responsable = COALESCE(p_id_responsable, id_responsable),
        observaciones = CASE
            WHEN p_observaciones IS NULL THEN observaciones
            ELSE NULLIF(TRIM(p_observaciones), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
        UPDATE gre_guia_remision_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_guia_remision = p_id AND estado = 1;

        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;

            IF (v_detalle->>'idProducto') IS NULL
               AND (v_detalle->>'id_producto') IS NULL
               AND (v_detalle->>'idBalon') IS NULL
               AND (v_detalle->>'id_balon') IS NULL
               AND NULLIF(TRIM(COALESCE(v_detalle->>'glosa', v_detalle->>'descripcion', '')), '') IS NULL
            THEN
                RETURN json_build_object(
                    'error',
                    format('Ítem %s: indica cilindro, producto o descripción', v_item),
                    'registro',
                    NULL
                );
            END IF;

            IF COALESCE((v_detalle->>'cantidad')::NUMERIC, 0) <= 0 THEN
                RETURN json_build_object('error', format('Ítem %s: cantidad inválida', v_item), 'registro', NULL);
            END IF;

            INSERT INTO gre_guia_remision_detalle (
                id_guia_remision, item, id_producto, descripcion,
                id_unidad_medida, cantidad, id_balon, glosa,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_detalle->>'item')::INTEGER, v_item),
                COALESCE((v_detalle->>'idProducto')::INTEGER, (v_detalle->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_detalle->>'descripcion', '')), ''),
                COALESCE((v_detalle->>'idUnidadMedida')::INTEGER, (v_detalle->>'id_unidad_medida')::INTEGER),
                (v_detalle->>'cantidad')::NUMERIC,
                COALESCE((v_detalle->>'idBalon')::INTEGER, (v_detalle->>'id_balon')::INTEGER),
                NULLIF(TRIM(COALESCE(v_detalle->>'glosa', '')), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            v_id_balon_linea := COALESCE(
                (v_detalle->>'idBalon')::INTEGER,
                (v_detalle->>'id_balon')::INTEGER
            );
            IF v_id_balon_linea IS NOT NULL THEN
                v_ids_conservar := array_append(v_ids_conservar, v_id_balon_linea);
            END IF;
        END LOOP;
    END IF;

    IF p_referencias IS NOT NULL AND json_typeof(p_referencias) = 'array' THEN
        UPDATE gre_documentos_referencia
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_guia_remision = p_id AND estado = 1;

        FOR v_ref IN SELECT value FROM json_array_elements(p_referencias)
        LOOP
            INSERT INTO gre_documentos_referencia (
                id_guia_remision, id_tipo_comprobante, id_comprobante, serie, numero, fecha,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_ref->>'idTipoComprobante')::INTEGER, (v_ref->>'id_tipo_comprobante')::INTEGER),
                COALESCE((v_ref->>'idComprobante')::INTEGER, (v_ref->>'id_comprobante')::INTEGER),
                NULLIF(UPPER(TRIM(COALESCE(v_ref->>'serie', ''))), ''),
                NULLIF(TRIM(COALESCE(v_ref->>'numero', '')), ''),
                NULLIF(v_ref->>'fecha', '')::DATE,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_detalles IS NOT NULL THEN
        v_rev := bal_revertir_salidas_guia_remision(p_id, v_ids_conservar, p_id_usuario_auditoria);
        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;
    END IF;

    -- CY1: salidas idempotentes para cilindros presentes en la guía
    v_salidas := bal_aplicar_salidas_guia_remision(p_id, p_id_usuario_auditoria);
    IF v_salidas->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_salidas->>'error';
    END IF;

    RETURN gre_obtener_guia_remision(p_id);
END;
$function$;

-- GRE remitente PENDIENTE ligada al CPE cuando el POS presta cilindros.
-- Si faltan flota, ubigeo o sucursal, no aborta la venta.
CREATE OR REPLACE FUNCTION ven_pos_crear_guia_remision(
    p_id_comprobante INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_comp RECORD;
    v_id_tipo INTEGER;
    v_id_motivo INTEGER;
    v_id_modalidad INTEGER;
    v_id_unidad INTEGER;
    v_id_chofer INTEGER;
    v_id_vehiculo INTEGER;
    v_serie VARCHAR;
    v_dir_origen VARCHAR;
    v_id_dist_origen INTEGER;
    v_dir_llegada VARCHAR;
    v_id_dist_llegada INTEGER;
    v_peso NUMERIC;
    v_detalles JSON;
    v_referencias JSON;
    v_result JSON;
    v_n INTEGER;
    v_id_guia INTEGER;
    v_serie_guia VARCHAR;
    v_numero_guia VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_n
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL;

    IF COALESCE(v_n, 0) = 0 THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM gre_documentos_referencia r
        INNER JOIN gre_guia_remision g ON g.id = r.id_guia_remision AND g.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        WHERE r.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
    ) THEN
        RETURN;
    END IF;

    SELECT
        c.id,
        c.serie,
        c.numero,
        c.fecha,
        c.id_tipo_comprobante,
        c.id_cliente,
        c.id_sucursal,
        c.id_almacen
    INTO v_comp
    FROM ven_comprobante c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF v_comp.id_sucursal IS NULL OR v_comp.id_almacen IS NULL OR v_comp.id_cliente IS NULL THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoGuiaRemision' AND lo.descripcion = '09' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_motivo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MotivoTraslado' AND lo.nombre = 'VENTA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_modalidad
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ModalidadTraslado' AND lo.descripcion = '02' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_unidad
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'UnidadMedida'
      AND UPPER(lo.nombre) IN ('KGM', 'KG')
      AND lo.estado = 1
    ORDER BY CASE UPPER(lo.nombre) WHEN 'KGM' THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT id INTO v_id_chofer FROM gen_chofer WHERE estado = 1 ORDER BY id LIMIT 1;
    SELECT id INTO v_id_vehiculo
    FROM gen_vehiculo
    WHERE estado = 1 AND id_cliente IS NULL
    ORDER BY id
    LIMIT 1;

    SELECT s.direccion, s.id_distrito
    INTO v_dir_origen, v_id_dist_origen
    FROM gen_sucursal s
    WHERE s.id = v_comp.id_sucursal AND s.estado = 1;

    SELECT d.direccion, d.id_distrito
    INTO v_dir_llegada, v_id_dist_llegada
    FROM cli_direcciones d
    WHERE d.id_cliente = v_comp.id_cliente AND d.estado = 1
    ORDER BY d.es_principal DESC, d.id
    LIMIT 1;

    IF v_id_dist_llegada IS NULL THEN
        v_dir_llegada := v_dir_origen;
        v_id_dist_llegada := v_id_dist_origen;
    END IF;

    IF v_id_tipo IS NULL OR v_id_motivo IS NULL OR v_id_modalidad IS NULL
       OR v_id_unidad IS NULL
       OR v_id_dist_origen IS NULL OR v_id_dist_llegada IS NULL
       OR v_id_chofer IS NULL OR v_id_vehiculo IS NULL
    THEN
        RETURN;
    END IF;

    SELECT COALESCE(
        (
            SELECT g.serie
            FROM gre_guia_remision g
            WHERE g.estado = 1 AND LEFT(UPPER(g.serie), 1) = 'T'
            ORDER BY g.id DESC
            LIMIT 1
        ),
        'T001'
    ) INTO v_serie;

    SELECT COALESCE(json_agg(json_build_object(
        'idBalon', pd.id_balon,
        'idProducto', pd.id_producto,
        'cantidad', 1,
        'descripcion', 'Cilindro préstamo POS'
    )), '[]'::JSON)
    INTO v_detalles
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL;

    SELECT COALESCE(SUM(COALESCE(b.peso_aproximado_kg, tb.peso, 10)), 10)
    INTO v_peso
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    INNER JOIN bal_balon b ON b.id = pd.id_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1;

    v_referencias := json_build_array(json_build_object(
        'idTipoComprobante', v_comp.id_tipo_comprobante,
        'idComprobante', v_comp.id,
        'serie', v_comp.serie,
        'numero', v_comp.numero,
        'fecha', v_comp.fecha
    ));

    v_result := gre_crear_guia_remision(
        v_id_tipo,
        v_serie,
        NULL,
        v_comp.fecha,
        v_comp.fecha,
        v_comp.id_sucursal,
        v_comp.id_almacen,
        v_comp.id_cliente,
        v_id_motivo,
        v_id_unidad,
        GREATEST(v_peso, 0.1),
        v_n,
        v_dir_origen,
        v_id_dist_origen,
        v_comp.id_cliente,
        NULL,
        NULL,
        v_dir_llegada,
        v_id_dist_llegada,
        v_id_modalidad,
        NULL,
        v_id_chofer,
        v_id_vehiculo,
        NULL,
        'GRE automática POS — préstamo de cilindro',
        v_detalles,
        v_referencias,
        p_id_usuario,
        NULL,
        NULL
    );
    -- Si la GRE no se puede emitir (catálogo, correlativo, etc.), no aborta el POS.
    IF v_result->>'error' IS NOT NULL THEN
        RETURN;
    END IF;

    v_id_guia := (v_result->'registro'->>'id')::INTEGER;
    v_serie_guia := v_result->'registro'->>'serie';
    v_numero_guia := v_result->'registro'->>'numero';

    IF v_id_guia IS NULL THEN
        RETURN;
    END IF;

    -- Vínculo real detalle de préstamo ↔ GRE recién emitida. serie/numero se
    -- mantienen como snapshot para la UI que aún los lee.
    UPDATE bal_prestamo_detalle pd
    SET
        id_guia_entrega = v_id_guia,
        serie_guia_entrega = v_serie_guia,
        numero_guia_entrega = v_numero_guia,
        id_usuario_modificacion = COALESCE(p_id_usuario, pd.id_usuario_modificacion),
        fecha_modificacion = NOW()
    FROM bal_prestamo p
    WHERE p.id = pd.id_prestamo
      AND p.estado = 1
      AND p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL
      AND pd.id_guia_entrega IS NULL;
END;
$function$;

-- Cierra préstamo/recarga/alquiler/GRE pendientes ligados al CPE y suelta cilindros.
CREATE OR REPLACE FUNCTION ven_cerrar_custodia_comprobante(
    p_id_comprobante INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_origen RECORD;
    v_alquiler RECORD;
    v_alq_det RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_disp NUMERIC;
    v_sync JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
    v_id_tipo_doc_recarga INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    -- Préstamos: devolver cilindros pendientes y cerrar cabecera
    FOR v_prestamo IN
        SELECT id FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        FOR v_detalle IN
            SELECT id FROM bal_prestamo_detalle
            WHERE estado = 1 AND id_prestamo = v_prestamo.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_prestamo_detalle(
                v_detalle.id,
                CURRENT_DATE,
                NULL,
                p_id_usuario,
                'VACIO',
                'Devolución automática por anulación/NC del comprobante'
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

    -- Recargas mostrador: devolver m³ a orígenes y dar de baja el movimiento
    FOR v_recarga IN
        SELECT id, id_balon
        FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id_comprobante
    LOOP
        FOR v_origen IN
            SELECT id_balon, cantidad
            FROM bal_movimiento_recarga_origen
            WHERE id_movimiento_recarga = v_recarga.id AND estado = 1
        LOOP
            v_disp := COALESCE(bal_capacidad_disponible_balon(v_origen.id_balon), 0);
            v_sync := bal_sync_capacidad_restante(
                v_origen.id_balon,
                v_disp + COALESCE(v_origen.cantidad, 0),
                NULL,
                NULL,
                'FROM_M3',
                NULL,
                p_id_usuario
            );
            IF COALESCE((v_sync->>'ok')::BOOLEAN, FALSE) IS NOT TRUE THEN
                RAISE EXCEPTION '%', COALESCE(v_sync->>'error', 'No se pudo devolver la capacidad de recarga');
            END IF;
        END LOOP;

        UPDATE bal_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE estado = 1
          AND id_documento_ref = v_recarga.id
          AND (v_id_tipo_doc_recarga IS NULL OR id_tipo_documento_ref = v_id_tipo_doc_recarga);

        UPDATE bal_movimiento_recarga
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE id = v_recarga.id AND estado = 1;
    END LOOP;

    -- Alquileres: reingreso de regulador y cilindros de detalle
    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            'Devolución automática por anulación/NC del comprobante',
            NULL,
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

        FOR v_alq_det IN
            SELECT id FROM bal_alquiler_detalle
            WHERE estado = 1 AND id_alquiler = v_alquiler.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_alquiler_detalle(v_alq_det.id, CURRENT_DATE, NULL, p_id_usuario);
            PERFORM ven_raise_si_error(v_result);
        END LOOP;

        SELECT lo.id INTO v_id_estado_final
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, CURRENT_DATE),
            id_estado = COALESCE(v_id_estado_final, id_estado),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_alquiler.id AND estado = 1;
    END LOOP;

    -- GRE PENDIENTE que referencia este CPE
    FOR v_guia IN
        SELECT DISTINCT g.id
        FROM gre_guia_remision g
        INNER JOIN gre_documentos_referencia r ON r.id_guia_remision = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
    LOOP
        v_result := gre_eliminar_guia_remision(v_guia.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Mantenimiento no finalizado ligado al CPE
    FOR v_mant IN
        SELECT m.id, m.id_balon, em.nombre AS nombre_estado
        FROM bal_mantenimiento m
        LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
        WHERE m.estado = 1 AND m.id_comprobante_venta = p_id_comprobante
    LOOP
        IF UPPER(COALESCE(v_mant.nombre_estado, '')) = 'FINALIZADO' THEN
            CONTINUE;
        END IF;

        UPDATE bal_mantenimiento
        SET
            estado = 0,
            id_comprobante_venta = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_mant.id AND estado = 1;

        SELECT lo.id INTO v_id_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon b
        SET
            id_estado_balon = COALESCE(v_id_en_almacen, b.id_estado_balon),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.id = v_mant.id_balon
          AND b.estado = 1
          AND EXISTS (
              SELECT 1 FROM gen_lista_opciones eb
              WHERE eb.id = b.id_estado_balon
                AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
          );
    END LOOP;

    -- Garantía sin reembolsos: se da de baja el cobro documental (el efectivo iba en el CPE)
    UPDATE ven_garantia_movimiento gm
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE gm.estado = 1
      AND gm.id_comprobante = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1
          FROM ven_garantia_movimiento d
          INNER JOIN gen_lista_opciones td ON td.id = d.id_tipo_movimiento
          WHERE d.id_garantia = gm.id_garantia
            AND d.estado = 1
            AND UPPER(td.nombre) = 'DEVOLUCION'
      );

    UPDATE ven_garantia g
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE g.estado = 1
      AND COALESCE(g.monto_devuelto, 0) = 0
      AND NOT EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm
          WHERE gm.id_garantia = g.id AND gm.estado = 1
      )
      AND EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm0
          WHERE gm0.id_garantia = g.id AND gm0.id_comprobante = p_id_comprobante
      );
END;
$function$;
