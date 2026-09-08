-- Function: doc_actualizar_salida_detalle
-- Corrige cantidad y glosa de una línea sin borrarla y volver a crearla.
--
-- Hasta ahora el detalle solo se podía agregar y quitar, así que cambiar una
-- cantidad obligaba a DELETE + POST: eso renumera el item y deja huecos en la
-- secuencia. En planta externa la cantidad de gas se consolida en una línea por
-- producto y se ajusta varias veces antes de generar, que es justo el caso que
-- esto resuelve.
--
-- Mismas dos guardas que doc_crear_salida_detalle y doc_eliminar_salida_detalle
-- (estado BORRADOR, documento sin id_venta): en BORRADOR la línea todavía no
-- generó movimiento, así que no hay inventario que revertir.
--
-- NULL = no cambiar (convención de doc_actualizar_traslado). Para vaciar la
-- glosa se envía cadena vacía.
DROP FUNCTION IF EXISTS doc_actualizar_salida_detalle(p_id integer, p_cantidad numeric, p_glosa character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_actualizar_salida_detalle(p_id integer, p_cantidad numeric DEFAULT NULL::numeric, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT dd.*, d.id_venta, ec.nombre AS estado_ciclo
    INTO v_det
    FROM doc_salida_detalle dd
    JOIN doc_salida d ON d.id = dd.id_doc_salida
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE dd.id = p_id AND dd.estado = 1 AND d.estado = 1
    FOR UPDATE OF dd;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La línea no existe o ya fue eliminada', 'registro', NULL);
    END IF;

    IF v_det.id_venta IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'Este documento toma su detalle de la venta asociada; no admite líneas propias',
            'registro', NULL
        );
    END IF;

    IF v_det.estado_ciclo <> 'BORRADOR' THEN
        RETURN json_build_object(
            'error', format('No se puede editar el detalle: el documento está %s', v_det.estado_ciclo),
            'registro', NULL
        );
    END IF;

    IF p_cantidad IS NOT NULL AND p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    UPDATE doc_salida_detalle
    SET cantidad = COALESCE(p_cantidad, cantidad),
        glosa = CASE
                    WHEN p_glosa IS NULL THEN glosa
                    WHEN TRIM(p_glosa) = '' THEN NULL
                    ELSE p_glosa
                END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(v_det.id_doc_salida);
END;
$function$;
