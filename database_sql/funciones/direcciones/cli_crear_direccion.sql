DROP FUNCTION IF EXISTS cli_crear_direccion(
    INTEGER,
    VARCHAR,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER,
    VARCHAR,
    BOOLEAN,
    INTEGER
);
CREATE OR REPLACE FUNCTION cli_crear_direccion(
    p_id_cliente INTEGER,
    p_direccion VARCHAR,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_departamento INTEGER DEFAULT NULL,
    p_id_provincia INTEGER DEFAULT NULL,
    p_id_distrito INTEGER DEFAULT NULL,
    p_referencia VARCHAR DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_es_principal THEN
        UPDATE cli_direcciones
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_cliente = p_id_cliente AND estado = 1;
    END IF;

    INSERT INTO cli_direcciones (
        id_cliente,
        descripcion,
        direccion,
        id_departamento,
        id_provincia,
        id_distrito,
        referencia,
        es_principal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_descripcion,
        p_direccion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_referencia,
        COALESCE(p_es_principal, FALSE),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN cli_obtener_direccion(v_id);
END;
$function$;