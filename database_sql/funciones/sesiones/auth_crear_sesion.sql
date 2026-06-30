    CREATE OR REPLACE FUNCTION auth_crear_sesion(
        p_id_usuario INTEGER,
        p_token VARCHAR,
        p_ip VARCHAR DEFAULT NULL,
        p_user_agent VARCHAR DEFAULT NULL,
        p_id_usuario_auditoria INTEGER DEFAULT NULL
    )
    RETURNS JSON
    LANGUAGE plpgsql
    AS $function$
    DECLARE
        v_id INTEGER;
    BEGIN
        SET TIME ZONE 'America/Lima';

        INSERT INTO auth_sesiones (
            id_usuario, token, ip, user_agent,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_usuario, p_token, p_ip, p_user_agent,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN auth_obtener_sesion(v_id);
    END;
    $function$;
