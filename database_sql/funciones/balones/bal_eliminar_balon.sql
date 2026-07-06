CREATE OR REPLACE FUNCTION bal_eliminar_balon(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (SELECT 1 FROM bal_movimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene movimientos activos'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está en préstamos activos'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_alquiler_detalle WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque está en alquileres activos'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM bal_mantenimiento WHERE id_balon = p_id AND estado = 1) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar el balón porque tiene mantenimientos activos'
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
