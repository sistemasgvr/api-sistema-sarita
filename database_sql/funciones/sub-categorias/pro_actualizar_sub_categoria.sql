CREATE OR REPLACE FUNCTION pro_actualizar_sub_categoria(
    p_id INTEGER,
    p_id_categoria INTEGER DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
    v_id_categoria INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    SELECT COALESCE(p_id_categoria, id_categoria) INTO v_id_categoria
    FROM pro_sub_categoria
    WHERE id = p_id AND estado = 1;

    IF v_id_categoria IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_sub_categoria
        WHERE estado = 1
          AND id_categoria = v_id_categoria
          AND LOWER(TRIM(nombre)) = LOWER(v_nombre)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra subcategoría activa con el nombre ' || v_nombre || ' en esta categoría', 'registro', NULL);
    END IF;

    UPDATE pro_sub_categoria
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        nombre = COALESCE(v_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_sub_categoria(p_id);
END;
$function$;
