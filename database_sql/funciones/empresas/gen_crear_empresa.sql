DROP FUNCTION IF EXISTS gen_crear_empresa(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS gen_crear_empresa(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION gen_crear_empresa(
    p_ruc VARCHAR,
    p_razon_social VARCHAR DEFAULT NULL,
    p_nombre_comercial VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_tolerancia_m3_ruta_pueblo NUMERIC DEFAULT NULL,
    p_psi_minimo_util NUMERIC DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_empresa (
        ruc,
        razon_social,
        nombre_comercial,
        direccion,
        telefono,
        email,
        tolerancia_m3_ruta_pueblo,
        psi_minimo_util,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_ruc,
        p_razon_social,
        p_nombre_comercial,
        p_direccion,
        p_telefono,
        p_email,
        p_tolerancia_m3_ruta_pueblo,
        p_psi_minimo_util,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_empresa(v_id);
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;
