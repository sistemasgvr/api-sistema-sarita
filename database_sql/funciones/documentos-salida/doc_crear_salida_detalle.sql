-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_crear_salida_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_crear_salida_detalle(p_id_doc_salida integer, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_descripcion character varying, p_id_unidad_medida integer, p_glosa character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_crear_salida_detalle(p_id_doc_salida integer, p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_cantidad numeric DEFAULT 1, p_descripcion character varying DEFAULT NULL::character varying, p_id_unidad_medida integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_estado VARCHAR;
    v_item INTEGER;
    v_id_unidad INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id_doc_salida AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    v_estado := v_doc.estado_ciclo;

    IF v_doc.id_venta IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'Este documento toma su detalle de la venta asociada; no admite líneas propias',
            'registro', NULL
        );
    END IF;

    IF v_estado <> 'BORRADOR' THEN
        RETURN json_build_object(
            'error', format('No se puede editar el detalle: el documento está %s', v_estado),
            'registro', NULL
        );
    END IF;

    IF p_id_producto IS NULL AND p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'La línea debe indicar un producto o un balón', 'registro', NULL);
    END IF;

    IF COALESCE(p_cantidad, 0) <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND EXISTS (
        SELECT 1 FROM doc_salida_detalle
        WHERE id_doc_salida = p_id_doc_salida AND id_balon = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ese balón ya está en el documento', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(item), 0) + 1 INTO v_item
    FROM doc_salida_detalle WHERE id_doc_salida = p_id_doc_salida;

    v_id_unidad := COALESCE(
        p_id_unidad_medida,
        (SELECT id_unidad_medida FROM pro_producto WHERE id = p_id_producto)
    );

    INSERT INTO doc_salida_detalle (
        id_doc_salida, item, id_producto, id_balon, descripcion,
        id_unidad_medida, cantidad, glosa,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_doc_salida, v_item, p_id_producto, p_id_balon,
        COALESCE(p_descripcion, (SELECT nombre FROM pro_producto WHERE id = p_id_producto)),
        v_id_unidad, p_cantidad, p_glosa,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    );

    RETURN doc_obtener_salida(p_id_doc_salida);
END;
$function$;
