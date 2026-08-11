CREATE OR REPLACE FUNCTION bal_eliminar_ruta_pueblo(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre INTO v_estado
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Ruta no encontrada');
    END IF;

    IF v_estado = 'EN_RUTA' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar una ruta EN_RUTA; regístrela o cancélela'
        );
    END IF;

    UPDATE bal_ruta_pueblo_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_ruta_pueblo = p_id AND estado = 1;

    UPDATE bal_ruta_pueblo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
