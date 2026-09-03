-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_convertir_a_gre
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_fecha_traslado date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_serie VARCHAR;
    v_siguiente INTEGER;
    v_numero VARCHAR;
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

    -- El correlativo SUNAT se reserva ahora; si ya tenía uno, se conserva.
    IF v_doc.numero_sunat IS NOT NULL AND v_doc.serie = v_serie THEN
        v_numero := v_doc.numero_sunat;
    ELSE
        SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(numero_sunat, '\D', '', 'g'), '')::INTEGER), 0) + 1
        INTO v_siguiente
        FROM doc_salida
        WHERE serie = v_serie;

        v_numero := LPAD(v_siguiente::TEXT, 8, '0');
    END IF;

    UPDATE doc_salida
    SET id_tipo_guia_remision = COALESCE(p_id_tipo_guia_remision, id_tipo_guia_remision),
        serie = v_serie,
        numero_sunat = v_numero,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_modalidad_traslado = COALESCE(p_id_modalidad_traslado, id_modalidad_traslado),
        id_transportista = COALESCE(p_id_transportista, id_transportista),
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        id_vehiculo = COALESCE(p_id_vehiculo, id_vehiculo),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(p_direccion_origen, direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        direccion_llegada = COALESCE(p_direccion_llegada, direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado, fecha),
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
