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

CREATE OR REPLACE FUNCTION doc_actualizar_traslado(p_id integer, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_tipo_guia_remision integer DEFAULT NULL, p_id_chofer integer DEFAULT NULL, p_id_vehiculo integer DEFAULT NULL, p_id_transportista integer DEFAULT NULL, p_fecha_traslado date DEFAULT NULL)
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

    IF p_id_tipo_guia_remision IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_guia_remision AND descripcion IN ('09', '31')
    ) THEN
        RETURN json_build_object('error', 'Tipo de guía inválido', 'registro', NULL);
    END IF;
    IF EXISTS (SELECT 1 FROM doc_salida WHERE id = p_id AND serie IS NOT NULL
        AND p_id_tipo_guia_remision IS NOT NULL AND id_tipo_guia_remision IS DISTINCT FROM p_id_tipo_guia_remision) THEN
        RETURN json_build_object('error', 'Cambia el tipo de guía desde Editar datos GRE', 'registro', NULL);
    END IF;
    IF EXISTS (
        SELECT 1 FROM doc_salida d
        JOIN gen_lista_opciones tipo ON tipo.id = COALESCE(p_id_tipo_guia_remision, d.id_tipo_guia_remision)
        JOIN gen_lista_opciones modalidad ON modalidad.id = COALESCE(p_id_modalidad_traslado, d.id_modalidad_traslado)
        WHERE d.id = p_id AND tipo.descripcion = '31' AND modalidad.descripcion <> '01'
    ) THEN
        RETURN json_build_object('error', 'La guía de transportista requiere modalidad pública', 'registro', NULL);
    END IF;

    UPDATE doc_salida
    SET id_tipo_guia_remision = COALESCE(p_id_tipo_guia_remision, id_tipo_guia_remision),
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        id_vehiculo = COALESCE(p_id_vehiculo, id_vehiculo),
        id_transportista = COALESCE(p_id_transportista, id_transportista),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado),
        id_motivo_traslado    = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
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
