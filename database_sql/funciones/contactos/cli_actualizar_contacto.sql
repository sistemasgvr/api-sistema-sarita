DROP FUNCTION IF EXISTS cli_actualizar_contacto(INT, INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INT);

CREATE OR REPLACE FUNCTION cli_actualizar_contacto(
    p_id               INT,
    p_id_cliente       INT     DEFAULT NULL,
    p_nombre           VARCHAR DEFAULT NULL,
    p_apellido_paterno VARCHAR DEFAULT NULL,
    p_apellido_materno VARCHAR DEFAULT NULL,
    p_direccion        VARCHAR DEFAULT NULL,
    p_email            VARCHAR DEFAULT NULL,
    p_telefono1        VARCHAR DEFAULT NULL,
    p_telefono2        VARCHAR DEFAULT NULL,
    p_telefono3        VARCHAR DEFAULT NULL,
    p_es_principal     BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria       INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM cli_contacto WHERE id = p_id) THEN
        RETURN json_build_object('error', 'El contacto no existe', 'registro', NULL);
    END IF;

    -- Logica de contacto principal
    IF p_es_principal = TRUE THEN
        UPDATE cli_contacto 
        SET es_principal = FALSE 
        WHERE id_cliente = COALESCE(p_id_cliente, (SELECT id_cliente FROM cli_contacto WHERE id = p_id));
    END IF;

    UPDATE cli_contacto
    SET 
        id_cliente       = COALESCE(p_id_cliente, id_cliente),
        nombre           = COALESCE(p_nombre, nombre),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        direccion        = COALESCE(p_direccion, direccion),
        email            = COALESCE(p_email, email),
        telefono1        = COALESCE(p_telefono1, telefono1),
        telefono2        = COALESCE(p_telefono2, telefono2),
        telefono3        = COALESCE(p_telefono3, telefono3),
        es_principal     = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN cli_obtener_por_id_contacto(p_id);
END;
$$;