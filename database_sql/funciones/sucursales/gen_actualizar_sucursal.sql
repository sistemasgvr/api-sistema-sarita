CREATE OR REPLACE FUNCTION gen_actualizar_sucursal(
    p_id INTEGER,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_id_departamento INTEGER DEFAULT NULL,
    p_id_provincia INTEGER DEFAULT NULL,
    p_id_distrito INTEGER DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_sucursal
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        direccion = COALESCE(p_direccion, direccion),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_sucursal(p_id);
END;
$function$;
