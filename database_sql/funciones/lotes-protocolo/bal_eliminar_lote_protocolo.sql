-- Function: bal_eliminar_lote_protocolo
-- Fase 5 — baja lógica de la ficha ICP. No se permite si alguna recarga ya la
-- referencia: el historial de un cilindro no puede quedar apuntando al vacío.
DROP FUNCTION IF EXISTS bal_eliminar_lote_protocolo(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_lote_protocolo(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_usos INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Ficha de lote y protocolo no encontrada');
    END IF;

    SELECT
        (SELECT COUNT(*) FROM bal_movimiento_recarga r WHERE r.id_lote_protocolo = p_id AND r.estado = 1)
      + (SELECT COUNT(*) FROM doc_salida d WHERE d.id_lote_protocolo = p_id AND d.estado = 1)
    INTO v_usos;

    IF v_usos > 0 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', format('No se puede eliminar: %s recarga(s) referencian esta ficha', v_usos)
        );
    END IF;

    UPDATE bal_balon
    SET id_lote_protocolo_vigente = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo_vigente = p_id;

    UPDATE bal_lote_protocolo_envase
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo = p_id AND estado = 1;

    UPDATE bal_lote_protocolo_prueba
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_lote_protocolo = p_id AND estado = 1;

    UPDATE bal_lote_protocolo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
