CREATE OR REPLACE FUNCTION gen_crear_notificacion(
    p_id_usuario INTEGER,
    p_codigo_tipo VARCHAR,
    p_titulo VARCHAR,
    p_mensaje TEXT DEFAULT NULL,
    p_payload JSON DEFAULT '{}'::JSON,
    p_id_referencia INTEGER DEFAULT NULL,
    p_tipo_referencia VARCHAR DEFAULT NULL,
    p_clave_dedupe VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_codigo VARCHAR;
    v_clave VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario IS NULL THEN
        RETURN json_build_object('error', 'El destinatario es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth_usuarios WHERE id = p_id_usuario AND estado = TRUE) THEN
        RETURN json_build_object('error', 'El usuario destinatario no existe o está inactivo', 'registro', NULL);
    END IF;

    v_codigo := UPPER(TRIM(COALESCE(p_codigo_tipo, '')));
    IF v_codigo = '' THEN
        RETURN json_build_object('error', 'El tipo de notificación es obligatorio', 'registro', NULL);
    END IF;

    IF NULLIF(TRIM(p_titulo), '') IS NULL THEN
        RETURN json_build_object('error', 'El título es obligatorio', 'registro', NULL);
    END IF;

    v_clave := NULLIF(TRIM(p_clave_dedupe), '');

    IF v_clave IS NOT NULL THEN
        SELECT id INTO v_id
        FROM gen_notificacion
        WHERE id_usuario = p_id_usuario
          AND clave_dedupe = v_clave
          AND estado = 1
        LIMIT 1;

        IF v_id IS NOT NULL THEN
            RETURN (
                SELECT json_build_object(
                    'registro', (gen_obtener_notificacion(v_id, p_id_usuario))->'registro',
                    'creada', FALSE
                )
            );
        END IF;
    END IF;

    INSERT INTO gen_notificacion (
        id_usuario,
        codigo_tipo,
        titulo,
        mensaje,
        payload,
        id_referencia,
        tipo_referencia,
        clave_dedupe,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_usuario,
        v_codigo,
        TRIM(p_titulo),
        NULLIF(TRIM(p_mensaje), ''),
        COALESCE(p_payload, '{}'::JSON)::JSONB,
        p_id_referencia,
        NULLIF(TRIM(p_tipo_referencia), ''),
        v_clave,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN json_build_object(
        'registro', (gen_obtener_notificacion(v_id, p_id_usuario))->'registro',
        'creada', TRUE
    );
END;
$function$;
