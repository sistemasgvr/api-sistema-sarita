DROP FUNCTION IF EXISTS cli_obtener_por_id_contacto(INT);

CREATE OR REPLACE FUNCTION cli_obtener_por_id_contacto(
    p_id INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSON;
BEGIN
    SELECT json_build_object(
        'error', NULL,
        'registro', row_to_json(c)
    ) INTO v_resultado
    FROM (
        SELECT 
            co.id,
            co.id_cliente,
            co.nombre,
            co.apellido_paterno,
            co.apellido_materno,
            co.direccion,
            co.email,
            co.telefono1,
            co.telefono2,
            co.telefono3,
            co.es_principal,
            co.estado,
            co.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            co.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            co.fecha_creacion,
            co.fecha_modificacion
        FROM cli_contacto co
        LEFT JOIN auth_usuarios uc ON co.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON co.id_usuario_modificacion = um.id
        WHERE co.id = p_id
    ) c;

    IF v_resultado IS NULL THEN
        RETURN json_build_object('error', 'Contacto no encontrado', 'registro', NULL);
    END IF;

    RETURN v_resultado;
END;
$$;