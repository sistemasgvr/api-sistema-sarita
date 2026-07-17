DROP FUNCTION IF EXISTS cli_actualizar_direccion(
    INTEGER,
    INTEGER,
    VARCHAR,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    VARCHAR,
    NUMERIC(10,8),
    NUMERIC(11,8),
    BOOLEAN,
    INTEGER
);
CREATE OR REPLACE FUNCTION cli_actualizar_direccion(
    p_id INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_id_pais INTEGER DEFAULT NULL,
    p_id_departamento INTEGER DEFAULT NULL,
    p_id_provincia INTEGER DEFAULT NULL,
    p_id_distrito INTEGER DEFAULT NULL,
    p_referencia VARCHAR DEFAULT NULL,
    p_latitud NUMERIC(10,8) DEFAULT NULL,
    p_longitud NUMERIC(11,8) DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente INTO v_id_cliente
    FROM cli_direcciones
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_es_principal IS TRUE THEN
        UPDATE cli_direcciones
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1 AND id <> p_id;
    END IF;

    UPDATE cli_direcciones
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        direccion = COALESCE(p_direccion, direccion),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_pais = COALESCE(p_id_pais, id_pais),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        referencia = COALESCE(p_referencia, referencia),
        latitud = COALESCE(p_latitud, latitud),
        longitud = COALESCE(p_longitud, longitud),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN cli_obtener_por_id_direccion(p_id);
END;
$function$;