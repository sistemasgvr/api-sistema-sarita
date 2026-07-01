DROP FUNCTION IF EXISTS cli_listar_clientes(BOOLEAN, INT, VARCHAR, INT, INT);
CREATE OR REPLACE FUNCTION cli_listar_clientes(
    p_solo_activos    BOOLEAN  DEFAULT TRUE,
    p_id_tipo_cliente INT      DEFAULT NULL,
    p_busqueda        VARCHAR  DEFAULT NULL,
    p_limite          INT      DEFAULT 50,
    p_pagina          INT      DEFAULT 1
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSON;
BEGIN
    WITH filtrados AS (
        SELECT c.*
        FROM cli_clientes c
        WHERE (p_solo_activos = FALSE OR c.estado = 1)
          AND (p_id_tipo_cliente IS NULL OR c.id_tipo_cliente = p_id_tipo_cliente)
          AND (
                p_busqueda IS NULL
                OR c.razon_social ILIKE '%' || p_busqueda || '%'
                OR c.nombres ILIKE '%' || p_busqueda || '%'
                OR c.apellido_paterno ILIKE '%' || p_busqueda || '%'
                OR c.apellido_materno ILIKE '%' || p_busqueda || '%'
                OR c.numero_documento ILIKE '%' || p_busqueda || '%'
                OR c.codigo_interno ILIKE '%' || p_busqueda || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY razon_social NULLS LAST, nombres NULLS LAST
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

--ejemplo de uso listar general
select * FROM cli_listar_clientes();

--ejemplo de uso listar solo activos con limite y pagina
SELECT *
FROM cli_listar_clientes(
    p_solo_activos => TRUE,
    p_limite => 50,
    p_pagina => 1
);

---ejemplo de uso listar todos los clientes
SELECT *
FROM cli_listar_clientes(
    p_solo_activos => FALSE
);

--ejemplo de uso listar clientes por tipo de cliente
SELECT *
FROM cli_listar_clientes(
    p_id_tipo_cliente => 3
);

--ejemplo de uso buscar clientes razon social.
SELECT *
FROM cli_listar_clientes(
    p_busqueda => 'EMPRESA'
);

--ejemplo de uso buscar clientes por dni.
SELECT *
FROM cli_listar_clientes(
    p_busqueda => '70000001'
);

--ejemplo de uso buscar clientes por código interno.
SELECT *
FROM cli_listar_clientes(
    p_busqueda => 'CLI0005'
);

--ejemplo de uso buscar clientes por tipo de cliente y razón social.
SELECT *
FROM cli_listar_clientes(
    p_solo_activos => TRUE,
    p_id_tipo_cliente => 3,
    p_busqueda => 'EMPRESA'
);

--ejemplo de uso listar clientes con limite y pagina
SELECT *
FROM cli_listar_clientes(
    p_limite => 10,
    p_pagina => 1
);