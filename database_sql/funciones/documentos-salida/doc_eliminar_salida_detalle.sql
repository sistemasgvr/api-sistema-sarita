-- Fase 2 — quita una línea de un documento de salida que todavía está en
-- BORRADOR. Simétrica a doc_crear_salida_detalle: mismas dos guardas (estado
-- BORRADOR, sin id_venta) porque en BORRADOR ninguna línea generó movimiento
-- todavía (eso lo hace doc_generar_salida), así que no hay nada que revertir
-- en inv_movimiento — a diferencia de com_eliminar_compra_detalle, que sí
-- puede estar borrando una línea ya facturada/con stock movido.
DROP FUNCTION IF EXISTS doc_eliminar_salida_detalle(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_eliminar_salida_detalle(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
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
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_det.id_venta IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'Este documento toma su detalle de la venta asociada; no admite líneas propias'
        );
    END IF;

    IF v_det.estado_ciclo <> 'BORRADOR' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', format('No se puede editar el detalle: el documento está %s', v_det.estado_ciclo)
        );
    END IF;

    UPDATE doc_salida_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
