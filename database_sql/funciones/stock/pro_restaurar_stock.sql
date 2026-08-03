CREATE OR REPLACE FUNCTION pro_restaurar_stock(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INTEGER;
    v_id_almacen INTEGER;
    v_id_producto INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado, id_almacen, id_producto
    INTO v_estado, v_id_almacen, v_id_producto
    FROM pro_stock
    WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado = 1 THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede restaurar: el almacén está inactivo'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = v_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede restaurar: el producto está inactivo'
        );
    END IF;

    UPDATE pro_stock
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
