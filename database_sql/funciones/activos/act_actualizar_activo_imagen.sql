DROP FUNCTION IF EXISTS act_actualizar_activo_imagen(
    INTEGER,
    INTEGER,
    BOOLEAN,
    INTEGER,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_actualizar_activo_imagen(
    p_id                   INTEGER,
    p_orden                INTEGER DEFAULT NULL,
    p_es_principal         BOOLEAN = NULL,
    p_id_archivo           INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_activo INTEGER;
    v_ruta VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_activo INTO v_id_activo
    FROM act_activo_imagen
    WHERE id = p_id AND estado = 1;

    IF v_id_activo IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_archivo IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM gen_archivo WHERE id = p_id_archivo AND estado = 1) THEN
        RETURN json_build_object('error', 'Archivo no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE act_activo_imagen
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_activo = v_id_activo
          AND estado = 1
          AND id <> p_id
          AND es_principal = TRUE;
    END IF;

    UPDATE act_activo_imagen
    SET
        orden = COALESCE(p_orden, orden),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_archivo = COALESCE(p_id_archivo, id_archivo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- Si quedó como principal, reflejar la ruta en el activo
    IF COALESCE(p_es_principal, FALSE) = TRUE THEN
        SELECT a.ruta INTO v_ruta
        FROM act_activo_imagen ai
        INNER JOIN gen_archivo a ON ai.id_archivo = a.id
        WHERE ai.id = p_id;
        UPDATE act_activos
        SET imagen_principal_ruta = v_ruta,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_activo;
    END IF;

    RETURN act_obtener_activo_imagen(p_id);
END;
$function$;
