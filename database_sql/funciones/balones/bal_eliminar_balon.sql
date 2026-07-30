CREATE OR REPLACE FUNCTION bal_eliminar_balon(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT eb.nombre
    INTO v_estado_nombre
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.id = p_id AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Conservar historial: baja aprobada / robado no se descarta del libro
    IF v_estado_nombre IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar un cilindro dado de baja o robado. El historial se conserva para negociaciones con plantas.'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id AND estado = 1 AND estado_aprobacion = 'APROBADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar un cilindro con baja aprobada. Use el filtro «Dados de baja» para consultarlo.'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id AND estado = 1 AND estado_aprobacion = 'PENDIENTE'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar: hay una solicitud de baja pendiente. Apruebe o rechace la baja.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_movimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene movimientos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_movimiento_recarga WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene recargas. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está en préstamos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_alquiler_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está en alquileres. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_mantenimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene mantenimientos. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_balon_ph_historial WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene historial de P.H. Solicite baja para conservarlo.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_balon_estado_historial WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene historial de baja/reactivación. Solicite baja si corresponde.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está referenciado en comprobantes de venta.'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM gre_guia_remision_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está referenciado en guías de remisión.'
        );
    END IF;

    UPDATE bal_balon
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
