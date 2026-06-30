CREATE OR REPLACE FUNCTION gen_actualizar_configuracion_sunat(
    p_id INTEGER,
    p_id_empresa INTEGER DEFAULT NULL,
    p_usuario_sol VARCHAR DEFAULT NULL,
    p_clave_sol VARCHAR DEFAULT NULL,
    p_certificado_digital VARCHAR DEFAULT NULL,
    p_clave_certificado VARCHAR DEFAULT NULL,
    p_id_ambiente INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_configuracion_sunat
    SET
        id_empresa = COALESCE(p_id_empresa, id_empresa),
        usuario_sol = COALESCE(p_usuario_sol, usuario_sol),
        clave_sol = COALESCE(p_clave_sol, clave_sol),
        certificado_digital = COALESCE(p_certificado_digital, certificado_digital),
        clave_certificado = COALESCE(p_clave_certificado, clave_certificado),
        id_ambiente = COALESCE(p_id_ambiente, id_ambiente),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_configuracion_sunat(p_id);
END;
$function$;
