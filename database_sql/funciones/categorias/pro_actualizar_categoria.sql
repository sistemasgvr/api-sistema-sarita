CREATE OR REPLACE FUNCTION pro_actualizar_categoria(
    p_id INTEGER,
    p_nombre VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_categoria
        WHERE estado = 1
          AND LOWER(TRIM(nombre)) = LOWER(v_nombre)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otra categoría activa con el nombre ' || v_nombre, 'registro', NULL);
    END IF;

    UPDATE pro_categoria
    SET
        nombre = COALESCE(v_nombre, nombre),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_categoria(p_id);
END;
$function$;
