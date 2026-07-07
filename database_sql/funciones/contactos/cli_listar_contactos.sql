DROP FUNCTION IF EXISTS cli_listar_contactos(INT, INT, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION cli_listar_contactos(
    p_solo_activos INT DEFAULT Null,
    p_id_cliente   INT     DEFAULT NULL,
    p_buscar       VARCHAR DEFAULT NULL,
    p_limite       INT     DEFAULT 50,
    p_pagina       INT     DEFAULT 1
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
                OR co.nombre ILIKE '%' || v_buscar || '%'
                OR co.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR co.apellido_materno ILIKE '%' || v_buscar || '%'
                OR co.email ILIKE '%' || v_buscar || '%'
                OR co.telefono1 ILIKE '%' || v_buscar || '%'
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY es_principal DESC, nombre ASC, id DESC
        LIMIT p_limite 
        OFFSET GREATEST(p_pagina - 1, 0) * p_limite
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;
