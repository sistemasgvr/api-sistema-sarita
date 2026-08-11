DROP FUNCTION IF EXISTS gen_actualizar_empresa(INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, NUMERIC, INTEGER);
DROP FUNCTION IF EXISTS gen_actualizar_empresa(INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_empresa(
    p_id INTEGER,
    p_ruc VARCHAR DEFAULT NULL,
    p_razon_social VARCHAR DEFAULT NULL,
    p_nombre_comercial VARCHAR DEFAULT NULL,
    p_direccion VARCHAR DEFAULT NULL,
    p_telefono VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_tolerancia_m3_ruta_pueblo NUMERIC DEFAULT NULL,
    p_psi_minimo_util NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_tolerancia_m3_ruta_pueblo IS NOT NULL AND p_tolerancia_m3_ruta_pueblo < 0 THEN
        RETURN json_build_object('error', 'La tolerancia de ruta pueblos no puede ser negativa', 'registro', NULL);
    END IF;

    IF p_psi_minimo_util IS NOT NULL AND p_psi_minimo_util < 0 THEN
        RETURN json_build_object('error', 'El umbral PSI mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    UPDATE gen_empresa
    SET
        ruc = COALESCE(p_ruc, ruc),
        razon_social = COALESCE(p_razon_social, razon_social),
        nombre_comercial = COALESCE(p_nombre_comercial, nombre_comercial),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        tolerancia_m3_ruta_pueblo = COALESCE(p_tolerancia_m3_ruta_pueblo, tolerancia_m3_ruta_pueblo),
        psi_minimo_util = COALESCE(p_psi_minimo_util, psi_minimo_util),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id);
END;
$function$;
