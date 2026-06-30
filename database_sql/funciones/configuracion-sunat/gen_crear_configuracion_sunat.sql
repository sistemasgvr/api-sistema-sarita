CREATE OR REPLACE FUNCTION gen_crear_configuracion_sunat(
    p_id_empresa INTEGER,
    p_usuario_sol VARCHAR,
    p_clave_sol VARCHAR,
    p_certificado_digital VARCHAR DEFAULT NULL,
    p_clave_certificado VARCHAR DEFAULT NULL,
    p_id_ambiente INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_sunat (
        id_empresa,
        usuario_sol,
        clave_sol,
        certificado_digital,
        clave_certificado,
        id_ambiente,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_empresa,
        p_usuario_sol,
        p_clave_sol,
        p_certificado_digital,
        p_clave_certificado,
        p_id_ambiente,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_sunat(v_id);
END;
$function$;
