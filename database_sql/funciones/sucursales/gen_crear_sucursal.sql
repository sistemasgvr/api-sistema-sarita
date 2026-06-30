CREATE OR REPLACE FUNCTION gen_crear_sucursal(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
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
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_sucursal (
        codigo,
        nombre,
        direccion,
        id_departamento,
        id_provincia,
        id_distrito,
        telefono,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_direccion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_telefono,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_sucursal(v_id);
END;
$function$;
