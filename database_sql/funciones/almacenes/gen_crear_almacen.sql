CREATE OR REPLACE FUNCTION gen_crear_almacen(
    p_id_sucursal INTEGER,
    p_nombre VARCHAR,
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
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_almacen (
        id_sucursal,
        nombre,
        ubicacion,
        descripcion,
        id_departamento,
        id_provincia,
        id_distrito,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_sucursal,
        p_nombre,
        p_ubicacion,
        p_descripcion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_almacen(v_id);
END;
$function$;
