CREATE OR REPLACE FUNCTION pro_crear_categoria(
    p_nombre VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la categoría es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_categoria
        WHERE estado = 1 AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
    ) THEN
        RETURN json_build_object('error', 'Ya existe una categoría activa con el nombre ' || TRIM(p_nombre), 'registro', NULL);
    END IF;

    INSERT INTO pro_categoria (
        nombre,
        descripcion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        TRIM(p_nombre),
        p_descripcion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_categoria(v_id);
END;
$function$;
