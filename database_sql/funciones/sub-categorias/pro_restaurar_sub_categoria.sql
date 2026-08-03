CREATE OR REPLACE FUNCTION pro_restaurar_sub_categoria(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INTEGER;
    v_nombre VARCHAR;
    v_id_categoria INTEGER;
    v_categoria_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT sc.estado, sc.nombre, sc.id_categoria, c.estado
    INTO v_estado, v_nombre, v_id_categoria, v_categoria_estado
    FROM pro_sub_categoria sc
    INNER JOIN pro_categoria c ON c.id = sc.id_categoria
    WHERE sc.id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado = 1 THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_categoria_estado <> 1 THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede restaurar: la categoría padre está inactiva'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pro_sub_categoria
        WHERE id <> p_id
          AND id_categoria = v_id_categoria
          AND estado = 1
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(v_nombre))
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Ya existe una subcategoría activa con el mismo nombre en esa categoría'
        );
    END IF;

    UPDATE pro_sub_categoria
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
