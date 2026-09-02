-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gre_actualizar_guia_remision
-- Overloads: 2
-- Generated: 2026-09-02T21:31:03.754Z
DROP FUNCTION IF EXISTS gre_actualizar_guia_remision(p_id integer, p_fecha date, p_fecha_traslado date, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_id_motivo_traslado integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_id_destinatario integer, p_destinatario_nombre character varying, p_destinatario_documento character varying, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_responsable integer, p_observaciones character varying, p_detalles json, p_referencias json, p_id_usuario_auditoria integer, p_remitente_nombre character varying, p_remitente_documento character varying);

CREATE OR REPLACE FUNCTION gre_actualizar_guia_remision(p_id integer, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_destinatario_nombre character varying DEFAULT NULL::character varying, p_destinatario_documento character varying DEFAULT NULL::character varying, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_detalles json DEFAULT NULL::json, p_referencias json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_remitente_nombre character varying DEFAULT NULL::character varying, p_remitente_documento character varying DEFAULT NULL::character varying)
 RETURNS json
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
$function$

DROP FUNCTION IF EXISTS gre_actualizar_guia_remision(p_id integer, p_fecha date, p_fecha_traslado date, p_id_sucursal integer, p_id_almacen integer, p_id_cliente integer, p_id_motivo_traslado integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_id_destinatario integer, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_responsable integer, p_observaciones character varying, p_detalles json, p_referencias json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gre_actualizar_guia_remision(p_id integer, p_fecha date DEFAULT NULL::date, p_fecha_traslado date DEFAULT NULL::date, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_id_destinatario integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_detalles json DEFAULT NULL::json, p_referencias json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_codigo_modalidad VARCHAR;
    v_id_tipo INTEGER;
    v_id_modalidad INTEGER;
    v_id_destinatario INTEGER;
    v_id_distrito_origen INTEGER;
    v_id_distrito_llegada INTEGER;
    v_peso NUMERIC;
    v_detalle JSON;
    v_ref JSON;
    v_item INTEGER := 0;
    v_salidas JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, g.id_tipo_guia_remision
    INTO v_estado_sunat, v_id_tipo
    FROM gre_guia_remision g
    LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
    WHERE g.id = p_id AND g.estado = 1;

    IF v_estado_sunat IS NULL AND v_id_tipo IS NULL THEN
        RETURN json_build_object('error', 'GuÃ­a de remisiÃ³n no encontrada', 'registro', NULL);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'error', 'No se puede editar una guÃ­a aceptada por SUNAT',
            'registro', NULL
        );
    END IF;

    SELECT
        COALESCE(p_id_modalidad_traslado, g.id_modalidad_traslado),
        COALESCE(p_id_destinatario, g.id_destinatario),
        COALESCE(p_id_distrito_origen, g.id_distrito_origen),
        COALESCE(p_id_distrito_llegada, g.id_distrito_llegada),
        COALESCE(p_peso_bruto, g.peso_bruto)
    INTO
        v_id_modalidad,
        v_id_destinatario,
        v_id_distrito_origen,
        v_id_distrito_llegada,
        v_peso
    FROM gre_guia_remision g
    WHERE g.id = p_id AND g.estado = 1;

    IF v_id_destinatario IS NULL THEN
        RETURN json_build_object('error', 'El destinatario es obligatorio', 'registro', NULL);
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
        RETURN json_build_object('error', 'Transporte privado requiere chofer y vehÃ­culo', 'registro', NULL);
    END IF;

    IF v_codigo_modalidad = '01'
       AND COALESCE(p_id_transportista, (SELECT id_transportista FROM gre_guia_remision WHERE id = p_id)) IS NULL
    THEN
        RETURN json_build_object('error', 'Transporte pÃºblico requiere transportista', 'registro', NULL);
    END IF;

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un Ã­tem', 'registro', NULL);
        END IF;
    END IF;

    UPDATE gre_guia_remision
    SET
        fecha = COALESCE(p_fecha, fecha),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(NULLIF(TRIM(p_direccion_origen), ''), direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        id_destinatario = COALESCE(p_id_destinatario, id_destinatario),
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
                id_guia_remision, id_tipo_comprobante, serie, numero, fecha,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_ref->>'idTipoComprobante')::INTEGER, (v_ref->>'id_tipo_comprobante')::INTEGER),
                NULLIF(UPPER(TRIM(COALESCE(v_ref->>'serie', ''))), ''),
                NULLIF(TRIM(COALESCE(v_ref->>'numero', '')), ''),
                NULLIF(v_ref->>'fecha', '')::DATE,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- CY1: salidas idempotentes para cilindros presentes en la guÃ­a
    v_salidas := bal_aplicar_salidas_guia_remision(p_id, p_id_usuario_auditoria);
    IF v_salidas->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_salidas->>'error';
    END IF;

    RETURN gre_obtener_guia_remision(p_id);
END;
$function$
