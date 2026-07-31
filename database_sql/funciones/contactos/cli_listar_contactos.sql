DROP FUNCTION IF EXISTS cli_listar_contactos(INT, INT, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION cli_listar_contactos(
    p_solo_activos INT DEFAULT NULL,
    p_id_cliente   INT     DEFAULT NULL,
    p_buscar       VARCHAR DEFAULT NULL,
    p_limite       INT     DEFAULT 10,
    p_offset       INT     DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    WITH filtrados AS (
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
        WHERE (p_solo_activos IS NULL OR co.estado = p_solo_activos)
          AND (p_id_cliente IS NULL OR co.id_cliente = p_id_cliente)
          AND (
                v_buscar IS NULL 
                OR gen_texto_coincide(co.nombre, v_buscar)
                OR gen_texto_coincide(co.apellido_paterno, v_buscar)
                OR gen_texto_coincide(co.apellido_materno, v_buscar)
                OR gen_texto_coincide(co.email, v_buscar)
                OR gen_texto_coincide(co.telefono1, v_buscar)
                OR gen_texto_coincide(c.razon_social, v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY es_principal DESC, nombre ASC, id DESC
        LIMIT p_limite 
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;
