CREATE OR REPLACE FUNCTION tra_eliminar_trabajador(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE tra_trabajadores
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Borrado lógico del usuario de acceso vinculado (si existe)
    UPDATE auth_usuarios
    SET estado = FALSE,
        fecha_modificacion = NOW()
    WHERE id = (SELECT id_usuario FROM tra_trabajadores WHERE id = p_id)
      AND estado = TRUE;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
