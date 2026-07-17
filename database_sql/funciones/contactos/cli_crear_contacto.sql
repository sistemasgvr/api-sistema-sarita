DROP FUNCTION IF EXISTS cli_crear_contacto(INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, INT);

CREATE OR REPLACE FUNCTION cli_crear_contacto(
    p_id_cliente       INT,
    p_nombre           VARCHAR DEFAULT NULL,
    p_apellido_paterno VARCHAR DEFAULT NULL,
    p_apellido_materno VARCHAR DEFAULT NULL,
    p_direccion        VARCHAR DEFAULT NULL,
    p_email            VARCHAR DEFAULT NULL,
    p_telefono1        VARCHAR DEFAULT NULL,
    p_telefono2        VARCHAR DEFAULT NULL,
    p_telefono3        VARCHAR DEFAULT NULL,
    p_es_principal     BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria       INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El id_cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_nombre IS NULL THEN
        RETURN json_build_object('error', 'El nombre del contacto es obligatorio', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE cli_contacto 
        SET es_principal = FALSE 
        WHERE id_cliente = p_id_cliente;
    END IF;

    INSERT INTO cli_contacto (
        id_cliente, nombre, apellido_paterno, apellido_materno, 
        direccion, email, telefono1, telefono2, telefono3, 
        es_principal, estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_nombre, p_apellido_paterno, p_apellido_materno, 
        p_direccion, p_email, p_telefono1, p_telefono2, p_telefono3, 
        p_es_principal, 1, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_por_id_contacto(v_id);
END;
$$;