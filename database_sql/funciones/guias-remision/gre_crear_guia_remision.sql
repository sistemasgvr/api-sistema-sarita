-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gre_crear_guia_remision
-- Overloads: 2
-- Generated: 2026-09-02T21:31:03.755Z
DROP FUNCTION IF EXISTS gre_crear_guia_remision(p_id_tipo_guia_remision integer, p_serie character varying, p_numero character varying, p_fecha date, p_fecha_traslado date, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_id_motivo_traslado integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_id_destinatario integer, p_destinatario_nombre character varying, p_destinatario_documento character varying, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_responsable integer, p_observaciones character varying, p_detalles json, p_referencias json, p_id_usuario_auditoria integer, p_remitente_nombre character varying, p_remitente_documento character varying);

CREATE OR REPLACE FUNCTION gre_crear_guia_remision(p_id_tipo_guia_remision integer, p_serie character varying, p_numero character varying DEFAULT NULL::character varying, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_destinatario_nombre character varying DEFAULT NULL::character varying, p_destinatario_documento character varying DEFAULT NULL::character varying, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_referencias json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_remitente_nombre character varying DEFAULT NULL::character varying, p_remitente_documento character varying DEFAULT NULL::character varying)
 RETURNS json
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
$function$

DROP FUNCTION IF EXISTS gre_crear_guia_remision(p_id_tipo_guia_remision integer, p_serie character varying, p_numero character varying, p_fecha date, p_fecha_traslado date, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_id_motivo_traslado integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_id_destinatario integer, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_responsable integer, p_observaciones character varying, p_detalles json, p_referencias json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gre_crear_guia_remision(p_id_tipo_guia_remision integer, p_serie character varying, p_numero character varying DEFAULT NULL::character varying, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_referencias json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_fecha_traslado := COALESCE(p_fecha_traslado, v_fecha);

    IF p_id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guÃ­a es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NULL OR p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'Sucursal y almacÃ©n son obligatorios', 'registro', NULL);
    END IF;

    IF p_id_destinatario IS NULL THEN
        RETURN json_build_object('error', 'El destinatario es obligatorio', 'registro', NULL);
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
        RETURN json_build_object('error', 'Debe registrar al menos un Ã­tem', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_guia_remision AND lo.estado = 1;

    IF v_codigo_tipo IS NULL THEN
        RETURN json_build_object('error', 'Tipo de guÃ­a invÃ¡lido', 'registro', NULL);
    END IF;

    -- Serie GRE remitente inicia con T; transportista con V (convenciÃ³n SUNAT)
    IF v_codigo_tipo = '09' AND LEFT(v_serie, 1) <> 'T' THEN
        RETURN json_build_object('error', 'La serie de GRE remitente (09) debe iniciar con T (ej. T001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '31' AND LEFT(v_serie, 1) <> 'V' THEN
        RETURN json_build_object('error', 'La serie de GRE transportista (31) debe iniciar con V (ej. V001)', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_modalidad
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_modalidad_traslado AND lo.estado = 1;

    IF v_codigo_modalidad = '02' AND (p_id_chofer IS NULL OR p_id_vehiculo IS NULL) THEN
        RETURN json_build_object('error', 'Transporte privado requiere chofer y vehÃ­culo', 'registro', NULL);
    END IF;

    IF v_codigo_modalidad = '01' AND p_id_transportista IS NULL THEN
        RETURN json_build_object('error', 'Transporte pÃºblico requiere transportista', 'registro', NULL);
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
        RETURN json_build_object('error', 'Ya existe una guÃ­a con esa serie y nÃºmero', 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO gre_guia_remision (
            id_tipo_guia_remision, serie, numero, id_estado_sunat,
            fecha, tipo_cambio, id_sucursal, id_almacen, id_cliente,
            fecha_traslado, id_motivo_traslado, id_unidad_medida,
            peso_bruto, numero_bultos,
            direccion_origen, id_distrito_origen,
            id_destinatario, direccion_llegada, id_distrito_llegada,
            id_modalidad_traslado, id_transportista, id_chofer, id_vehiculo,
            id_responsable, observaciones, id_estado,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            p_id_tipo_guia_remision, v_serie, v_numero, v_id_estado_sunat,
            v_fecha, 3.5, p_id_sucursal, p_id_almacen, p_id_cliente,
            v_fecha_traslado, p_id_motivo_traslado, p_id_unidad_medida,
            p_peso_bruto, COALESCE(p_numero_bultos, 1),
            NULLIF(TRIM(p_direccion_origen), ''), p_id_distrito_origen,
            p_id_destinatario, NULLIF(TRIM(p_direccion_llegada), ''), p_id_distrito_llegada,
            p_id_modalidad_traslado, p_id_transportista, p_id_chofer, p_id_vehiculo,
            p_id_responsable, NULLIF(TRIM(p_observaciones), ''), v_id_estado,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe una guÃ­a con esa serie y nÃºmero', 'registro', NULL);
    END;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        IF (v_detalle->>'idProducto') IS NULL AND (v_detalle->>'id_producto') IS NULL THEN
            RETURN json_build_object('error', format('Ãtem %s: producto obligatorio', v_item), 'registro', NULL);
        END IF;

        IF COALESCE((v_detalle->>'cantidad')::NUMERIC, 0) <= 0 THEN
            RETURN json_build_object('error', format('Ãtem %s: cantidad invÃ¡lida', v_item), 'registro', NULL);
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
                id_guia_remision, id_tipo_comprobante, serie, numero, fecha,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                COALESCE((v_ref->>'idTipoComprobante')::INTEGER, (v_ref->>'id_tipo_comprobante')::INTEGER),
                NULLIF(UPPER(TRIM(COALESCE(v_ref->>'serie', ''))), ''),
                NULLIF(TRIM(COALESCE(v_ref->>'numero', '')), ''),
                NULLIF(v_ref->>'fecha', '')::DATE,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- CY1: salida automÃ¡tica de cilindros con cÃ³digo en la GRE
    v_salidas := bal_aplicar_salidas_guia_remision(v_id, p_id_usuario_auditoria);
    IF v_salidas->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_salidas->>'error';
    END IF;

    RETURN gre_obtener_guia_remision(v_id);
END;
$function$
