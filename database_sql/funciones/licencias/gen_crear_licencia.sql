DROP FUNCTION IF EXISTS gen_crear_licencia(
    VARCHAR,
    INTEGER,
    DATE,
    DATE,
    INTEGER,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION gen_crear_licencia(
    p_codigo                  VARCHAR,
    p_id_chofer               INTEGER,
    p_fecha_emision           DATE,
    p_fecha_vencimiento       DATE,
    p_id_tipo_licencia        INTEGER DEFAULT NULL,
    p_id_categoria_licencia   INTEGER DEFAULT NULL,
    p_id_usuario_auditoria    INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_licencia (
        id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
        fecha_emision, fecha_vencimiento,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_licencia, p_id_categoria_licencia, p_id_chofer, p_codigo,
        p_fecha_emision, p_fecha_vencimiento,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_licencia(v_id);
END;
$function$;