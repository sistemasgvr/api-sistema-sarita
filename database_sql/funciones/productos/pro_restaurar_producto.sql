CREATE OR REPLACE FUNCTION pro_restaurar_producto(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado
    FROM pro_producto
    WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado = 1 THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE pro_producto
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
