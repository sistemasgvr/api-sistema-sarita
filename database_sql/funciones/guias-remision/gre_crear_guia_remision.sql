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
    p_id_usuario_auditoria INTEGER DEFAULT NULL
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
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_fecha_traslado := COALESCE(p_fecha_traslado, v_fecha);

    IF p_id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guía es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NULL OR p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'Sucursal y almacén son obligatorios', 'registro', NULL);
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
            RETURN json_build_object('error', 'Ya existe una guía con esa serie y número', 'registro', NULL);
    END;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        IF (v_detalle->>'idProducto') IS NULL AND (v_detalle->>'id_producto') IS NULL THEN
            RETURN json_build_object('error', format('Ítem %s: producto obligatorio', v_item), 'registro', NULL);
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

    RETURN gre_obtener_guia_remision(v_id);
END;
$function$;
