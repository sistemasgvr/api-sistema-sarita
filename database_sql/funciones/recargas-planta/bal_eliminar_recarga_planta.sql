CREATE OR REPLACE FUNCTION bal_eliminar_recarga_planta(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_det RECORD;
    v_del JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT est.nombre
    INTO v_estado
    FROM bal_recarga_planta rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
    WHERE rp.id = p_id AND rp.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Orden de recarga no encontrada', 'eliminado', FALSE);
    END IF;

    IF v_estado IN ('RETORNADO', 'CERRADO') THEN
        RETURN json_build_object(
            'error',
            'No se puede eliminar una orden retornada o cerrada',
            'eliminado',
            FALSE
        );
    END IF;

    FOR v_det IN
        SELECT id_movimiento_recarga
        FROM bal_recarga_planta_detalle
        WHERE id_recarga_planta = p_id AND estado = 1 AND id_movimiento_recarga IS NOT NULL
    LOOP
        v_del := bal_eliminar_movimiento_recarga(v_det.id_movimiento_recarga, p_id_usuario_auditoria);
        IF COALESCE((v_del->>'eliminado')::BOOLEAN, FALSE) IS NOT TRUE
           AND v_del->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_del->>'error', 'eliminado', FALSE);
        END IF;
    END LOOP;

    UPDATE bal_recarga_planta_detalle
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_recarga_planta = p_id AND estado = 1;

    UPDATE bal_recarga_planta
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
