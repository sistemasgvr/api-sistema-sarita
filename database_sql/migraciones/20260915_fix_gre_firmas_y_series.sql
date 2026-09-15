BEGIN;
SET LOCAL lock_timeout = '10s';
ALTER TABLE public.doc_salida ADD COLUMN IF NOT EXISTS id_empresa integer REFERENCES public.gen_empresa(id);
ALTER TABLE public.doc_salida ADD COLUMN IF NOT EXISTS gre_extra jsonb;
-- Firma única: empresa emisora y datos adicionales GRE.
-- Sustituye las variantes incompatibles de 17 y 18 parámetros, sin CASCADE.
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, json);

CREATE OR REPLACE FUNCTION public.doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_empresa integer DEFAULT NULL::integer, p_gre_extra json DEFAULT NULL::json)
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
    IF v_doc.numero_sunat IS NOT NULL AND v_doc.serie = v_serie THEN
        v_numero := v_doc.numero_sunat;
    ELSE
        -- Candado por serie dentro de la TX: evita dos GRE concurrentes con el mismo correlativo.
        PERFORM pg_advisory_xact_lock(872017, hashtext(v_serie));

        SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(numero_sunat, '\D', '', 'g'), '')::INTEGER), 0) + 1
        INTO v_siguiente
        FROM doc_salida
        WHERE serie = v_serie;

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

-- Series de guía de remisión disponibles para el modal "Convertir a GRE", con
-- el último correlativo usado y el siguiente a reservar (mismo criterio que
-- doc_convertir_a_gre: MAX(numero_sunat) por serie, incluyendo anuladas, para
-- no reutilizar números). Equivale a ven_obtener_siguiente_numero de boletas,
-- pero devolviendo todas las series ya usadas para elegirlas en un select.
--
-- El tipo de guía define el prefijo SUNAT: 09 GRE Remitente → T###,
-- 31 GRE Transportista → V###. Si aún no hay ninguna serie con ese prefijo se
-- ofrece la serie por defecto (T001 / V001) con correlativo 00000001.
DROP FUNCTION IF EXISTS doc_listar_series_gre(p_id_tipo_guia_remision integer);

CREATE OR REPLACE FUNCTION doc_listar_series_gre(p_id_tipo_guia_remision integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_prefijo VARCHAR;
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_guia_remision IS NOT NULL THEN
        SELECT TRIM(lo.descripcion)
        INTO v_codigo_tipo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_guia_remision;
    END IF;

    -- Sin tipo (o tipo desconocido) se asume remitente, el caso habitual.
    v_prefijo := CASE WHEN v_codigo_tipo = '31' THEN 'V' ELSE 'T' END;

    WITH usadas AS (
        SELECT
            UPPER(TRIM(d.serie)) AS serie,
            MAX(NULLIF(REGEXP_REPLACE(d.numero_sunat, '\D', '', 'g'), '')::INTEGER) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM doc_salida d
        WHERE d.serie IS NOT NULL
          AND d.numero_sunat IS NOT NULL
        GROUP BY UPPER(TRIM(d.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE v_prefijo || '%'
        UNION ALL
        SELECT v_prefijo || '001', NULL::INTEGER, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = v_prefijo || '001')
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;

COMMIT;
