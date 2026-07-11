DROP FUNCTION IF EXISTS gen_actualizar_licencia(
    INTEGER,
    INTEGER,
    VARCHAR,
    INTEGER,
    INTEGER,
    DATE,
    DATE,
    INTEGER
);
CREATE OR REPLACE FUNCTION gen_actualizar_licencia(
    p_id                      INTEGER,
    p_id_chofer               INTEGER DEFAULT NULL,
    p_codigo                  VARCHAR DEFAULT NULL,
    p_id_tipo_licencia        INTEGER DEFAULT NULL,
    p_id_categoria_licencia   INTEGER DEFAULT NULL,
    p_fecha_emision           DATE DEFAULT NULL,
    p_fecha_vencimiento       DATE DEFAULT NULL,
    p_id_usuario_auditoria    INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_licencia
    SET
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        codigo = COALESCE(p_codigo, codigo),
        id_tipo_licencia = COALESCE(p_id_tipo_licencia, id_tipo_licencia),
        id_categoria_licencia = COALESCE(p_id_categoria_licencia, id_categoria_licencia),
        fecha_emision = COALESCE(p_fecha_emision, fecha_emision),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_licencia(p_id);
END;
$function$;