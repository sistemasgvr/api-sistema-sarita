-- Firma única: empresa emisora y datos adicionales GRE.
-- Sustituye las variantes incompatibles de 17 y 18 parámetros, sin CASCADE.
--
-- Actualizada por database_sql/migraciones/20260916_gre_p0_fiscal_numeracion_entorno.sql:
-- el correlativo se reserva por empresa + serie (índice único
-- uq_doc_salida_empresa_serie_numero); antes era global por serie.
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, json);

DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer, json);

CREATE OR REPLACE FUNCTION public.doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_empresa integer DEFAULT NULL::integer, p_gre_extra json DEFAULT NULL::json, p_fecha_emision_gre date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_serie VARCHAR;
    v_siguiente INTEGER;
    v_numero VARCHAR;
    v_id_tipo_guia INTEGER;
    v_codigo_tipo_guia VARCHAR;
    v_id_modalidad INTEGER;
    v_codigo_modalidad VARCHAR;
    v_id_transportista INTEGER;
    v_id_chofer INTEGER;
    v_id_vehiculo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1 FOR UPDATE OF d;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF p_id_empresa IS NULL OR NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa AND estado = 1) THEN
        RETURN json_build_object('error', 'Selecciona una empresa emisora activa', 'registro', NULL);
    END IF;
    IF v_doc.id_empresa IS NOT NULL AND v_doc.id_empresa <> p_id_empresa AND v_doc.numero_sunat IS NOT NULL THEN
        RETURN json_build_object('error', 'La guía ya pertenece a otra empresa emisora', 'registro', NULL);
    END IF;
    IF v_doc.id_empresa IS NULL AND (v_doc.ticket_sunat IS NOT NULL OR COALESCE(v_doc.emitido_sunat, FALSE)) THEN
        RETURN json_build_object('error', 'Esta guía histórica requiere verificar su emisor antes de vincular una empresa', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'BORRADOR' THEN
        RETURN json_build_object(
            'error', 'Genera el documento antes de convertirlo en guía de remisión',
            'registro', NULL
        );
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object('error', 'El documento ya fue emitido a SUNAT', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM doc_gre_intento WHERE id_doc_salida = p_id AND estado <> 'RECHAZADO') THEN
        RETURN json_build_object('error', 'La GRE tiene un envío en curso, aceptado o pendiente de verificar', 'registro', NULL);
    END IF;
    IF COALESCE(p_fecha_emision_gre, v_doc.fecha_emision_gre) IS NULL THEN
        RETURN json_build_object('error', 'Indica la fecha de emisión de la GRE', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, v_doc.serie, '')));
    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie de la guía de remisión es obligatoria', 'registro', NULL);
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. T001, V001)', 'registro', NULL);
    END IF;

    IF p_id_tipo_guia_remision IS NULL AND v_doc.id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guía de remisión es obligatorio', 'registro', NULL);
    END IF;

    -- Tipo de guía y modalidad efectivos (lo enviado o lo ya guardado).
    v_id_tipo_guia := COALESCE(p_id_tipo_guia_remision, v_doc.id_tipo_guia_remision);
    SELECT TRIM(lo.descripcion) INTO v_codigo_tipo_guia
    FROM gen_lista_opciones lo WHERE lo.id = v_id_tipo_guia;

    v_id_modalidad := COALESCE(p_id_modalidad_traslado, v_doc.id_modalidad_traslado);

    -- GRE transportista (31): la empresa emisora ES el transportista, así que
    -- la modalidad SUNAT es siempre transporte público (01).
    IF v_codigo_tipo_guia = '31' THEN
        SELECT lo.id INTO v_id_modalidad
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'ModalidadTraslado' AND lo.nombre = 'PUBLICO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT TRIM(lo.descripcion) INTO v_codigo_modalidad
    FROM gen_lista_opciones lo WHERE lo.id = v_id_modalidad;

    -- Transporte según lo que SUNAT espera en cada caso; lo que no aplica se
    -- limpia para que ni el PDF ni el payload arrastren datos de una
    -- modalidad anterior.
    v_id_transportista := COALESCE(p_id_transportista, v_doc.id_transportista);
    v_id_chofer := COALESCE(p_id_chofer, v_doc.id_chofer);
    v_id_vehiculo := COALESCE(p_id_vehiculo, v_doc.id_vehiculo);

    IF v_codigo_tipo_guia = '31' THEN
        -- Vehículo y chofer propios; el transportista es la propia empresa.
        v_id_transportista := NULL;
    ELSIF v_codigo_modalidad = '01' THEN
        -- Público: un tercero con RUC lleva la carga con su propia flota.
        v_id_chofer := NULL;
        v_id_vehiculo := NULL;
    ELSIF v_codigo_modalidad = '02' THEN
        -- Privado: flota propia, sin transportista tercero.
        v_id_transportista := NULL;
    END IF;

    -- El correlativo SUNAT se reserva ahora; si ya tenía uno, se conserva.
    IF v_doc.numero_sunat IS NOT NULL AND v_doc.serie = v_serie AND v_doc.id_empresa = p_id_empresa THEN
        v_numero := v_doc.numero_sunat;
    ELSE
        -- Candado por empresa + serie dentro de la TX: dos empresas pueden usar
        -- la misma serie (cada RUC numera aparte en SUNAT) sin bloquearse ni
        -- colisionar; dos GRE concurrentes de la misma empresa se serializan.
        PERFORM pg_advisory_xact_lock(872017, hashtext(p_id_empresa::TEXT || '|' || v_serie));

        -- Se cuentan también los documentos anulados (no se reutilizan números)
        -- y los históricos sin empresa: mientras no se determine su emisor, es
        -- más seguro asumir que ese correlativo ya se usó ante SUNAT.
        SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(numero_sunat, '\D', '', 'g'), '')::INTEGER), 0) + 1
        INTO v_siguiente
        FROM doc_salida
        WHERE serie = v_serie AND (id_empresa = p_id_empresa OR id_empresa IS NULL);

        v_numero := LPAD(v_siguiente::TEXT, 8, '0');
    END IF;

    UPDATE doc_salida
    SET id_empresa = p_id_empresa,
        id_tipo_guia_remision = v_id_tipo_guia,
        serie = v_serie,
        numero_sunat = v_numero,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_modalidad_traslado = v_id_modalidad,
        id_transportista = v_id_transportista,
        id_chofer = v_id_chofer,
        id_vehiculo = v_id_vehiculo,
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(p_direccion_origen, direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        direccion_llegada = COALESCE(p_direccion_llegada, direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        fecha_emision_gre = COALESCE(p_fecha_emision_gre, fecha_emision_gre),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado, fecha),
        -- Datos opcionales SUNAT (indicadores, MTC, docBaja, tercero...). NULL = no tocar;
        -- {} = limpiar.
        gre_extra = COALESCE(p_gre_extra::jsonb, gre_extra),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    -- Si la orden nace de una venta, esa venta es su documento de referencia SUNAT.
    IF v_doc.id_venta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM doc_salida_referencia WHERE id_doc_salida = p_id AND id_comprobante = v_doc.id_venta AND estado = 1
    ) THEN
        INSERT INTO doc_salida_referencia (
            id_doc_salida, id_tipo_comprobante, id_comprobante, serie, numero, fecha,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT p_id, vc.id_tipo_comprobante, vc.id, vc.serie, vc.numero, vc.fecha,
               p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM ven_comprobante vc WHERE vc.id = v_doc.id_venta;
    END IF;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
