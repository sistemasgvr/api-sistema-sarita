DROP FUNCTION IF EXISTS act_crear_activo_imagen(
    INTEGER,
    INTEGER,
    INTEGER,
    BOOLEAN,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_crear_activo_imagen(
    p_id_activo            INTEGER,
    p_id_archivo           INTEGER,
    p_orden                INTEGER DEFAULT NULL,
    p_es_principal         BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_orden INTEGER;
    v_es_principal BOOLEAN;
    v_ruta VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_activo IS NULL THEN
        RETURN json_build_object('error', 'El id_activo es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM act_activos WHERE id = p_id_activo AND estado = 1) THEN
        RETURN json_build_object('error', 'Activo no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_id_archivo IS NULL THEN
        RETURN json_build_object('error', 'El id_archivo es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_archivo WHERE id = p_id_archivo AND estado = 1) THEN
        RETURN json_build_object('error', 'Archivo no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_orden IS NULL THEN
        SELECT COALESCE(MAX(orden), -1) + 1 INTO v_orden
        FROM act_activo_imagen
        WHERE id_activo = p_id_activo AND estado = 1;
    ELSE
        v_orden := p_orden;
    END IF;

    v_es_principal := COALESCE(p_es_principal, FALSE);

    -- Si es la primera imagen del activo, marcarla como principal
    IF v_es_principal = FALSE
       AND NOT EXISTS (
           SELECT 1 FROM act_activo_imagen
           WHERE id_activo = p_id_activo AND estado = 1
       ) THEN
        v_es_principal := TRUE;
    END IF;

    IF v_es_principal = TRUE THEN
        UPDATE act_activo_imagen
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_activo = p_id_activo
          AND estado = 1
          AND es_principal = TRUE;
    END IF;

    INSERT INTO act_activo_imagen (
        id_activo, id_archivo, orden, es_principal,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_activo, p_id_archivo, v_orden, v_es_principal,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Reflejar la imagen principal en la tabla del activo
    IF v_es_principal = TRUE THEN
        SELECT a.ruta INTO v_ruta FROM gen_archivo a WHERE a.id = p_id_archivo;
        UPDATE act_activos
        SET imagen_principal_ruta = v_ruta,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_activo;
    END IF;

    RETURN act_obtener_activo_imagen(v_id);
END;
$function$;
