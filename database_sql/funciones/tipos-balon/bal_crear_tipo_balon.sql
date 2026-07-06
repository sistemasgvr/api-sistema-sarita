CREATE OR REPLACE FUNCTION bal_crear_tipo_balon(
    p_nombre VARCHAR,
    p_id_gas INTEGER DEFAULT NULL,
    p_capacidad NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_peso NUMERIC DEFAULT NULL,
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
        RETURN json_build_object('error', 'El nombre del tipo de balón es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_tipo_balon
        WHERE estado = 1 AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un tipo de balón activo con el nombre ' || TRIM(p_nombre), 'registro', NULL);
    END IF;

    IF p_id_gas IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_gas AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El gas indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    INSERT INTO bal_tipo_balon (
        nombre, id_gas, capacidad, id_unidad_medida, peso,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_nombre), p_id_gas, p_capacidad, p_id_unidad_medida, p_peso,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_tipo_balon(v_id);
END;
$function$;
