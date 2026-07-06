CREATE OR REPLACE FUNCTION bal_actualizar_tipo_balon(
    p_id INTEGER,
    p_nombre VARCHAR DEFAULT NULL,
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
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_tipo_balon
        WHERE estado = 1 AND LOWER(TRIM(nombre)) = LOWER(v_nombre) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro tipo de balón con el nombre ' || v_nombre, 'registro', NULL);
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

    UPDATE bal_tipo_balon
    SET
        nombre = COALESCE(v_nombre, nombre),
        id_gas = COALESCE(p_id_gas, id_gas),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso = COALESCE(p_peso, peso),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_tipo_balon(p_id);
END;
$function$;
