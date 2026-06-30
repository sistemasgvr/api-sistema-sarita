CREATE OR REPLACE FUNCTION gen_actualizar_almacen(
    p_id INTEGER,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_ubicacion VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_departamento INTEGER DEFAULT NULL,
    p_id_provincia INTEGER DEFAULT NULL,
    p_id_distrito INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_almacen
    SET
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        nombre = COALESCE(p_nombre, nombre),
        ubicacion = COALESCE(p_ubicacion, ubicacion),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_almacen(p_id);
END;
$function$;
