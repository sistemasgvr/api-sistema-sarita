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
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
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
        LEFT JOIN cli_clientes c ON co.id_cliente = c.id
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