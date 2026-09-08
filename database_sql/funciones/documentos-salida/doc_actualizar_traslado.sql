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
