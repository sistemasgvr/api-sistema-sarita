DROP FUNCTION IF EXISTS cli_listar_clientes(INT, INT, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION cli_listar_clientes(
    p_solo_activos    INT  DEFAULT NULL,
    p_id_tipo_cliente INT      DEFAULT NULL,
    p_buscar          VARCHAR  DEFAULT NULL,
    p_limite          INT      DEFAULT 50,
    p_pagina          INT      DEFAULT 1
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
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.id_tipo_cliente,
            tc.nombre AS nombre_tipo_cliente,
            c.id_tipo_persona,
            tp.nombre AS nombre_tipo_persona,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            c.numero_documento,
            -- Dirección principal 
            dir.id            AS id_direccion,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            dir.id_departamento,
            dep.nombre         AS nombre_departamento,
            dir.id_provincia,
            prov.nombre        AS nombre_provincia,
            dir.id_distrito,
            dist.nombre        AS nombre_distrito,
            dir.id_pais,
            pa.nombre          AS nombre_pais,
            c.telefono,
            c.email,
            c.es_agente_percepcion,
            c.es_buen_contribuyente,
            c.es_agente_retenedor,
            c.afecto_rus,
            c.situacion_sunat,
            c.estado_contribuyente_sunat,
            c.observacion,
            c.estado,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_cliente = tc.id
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        LEFT JOIN gen_lista_opciones td ON c.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id

        LEFT JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.es_principal = TRUE
              AND cd.estado = 1
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE

        LEFT JOIN gen_departamento dep  ON dir.id_departamento = dep.id
        LEFT JOIN gen_provincia    prov ON dir.id_provincia    = prov.id
        LEFT JOIN gen_distrito     dist ON dir.id_distrito     = dist.id
        LEFT JOIN gen_pais         pa   ON dir.id_pais          = pa.id

        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_cliente IS NULL OR c.id_tipo_cliente = p_id_tipo_cliente)
          AND (
                v_buscar IS NULL
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR c.codigo_interno ILIKE '%' || v_buscar || '%'
                OR dir.direccion ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY razon_social NULLS LAST, nombres NULLS LAST, id DESC
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

/* CREATE OR REPLACE FUNCTION cli_listar_clientes(
    p_solo_activos    INT  DEFAULT 1,
    p_id_tipo_cliente INT      DEFAULT NULL,
    p_buscar          VARCHAR  DEFAULT NULL,
    p_limite          INT      DEFAULT 50,
    p_pagina          INT      DEFAULT 1
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
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.id_tipo_cliente,
            tc.nombre AS nombre_tipo_cliente,
            c.id_tipo_persona,
            tp.nombre AS nombre_tipo_persona,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            c.numero_documento,
            c.direccion,
            c.referencia,
            c.telefono,
            c.email,
            c.id_departamento,
            dep.nombre AS nombre_departamento,
            c.id_provincia,
            prov.nombre AS nombre_provincia,
            c.id_distrito,
            dist.nombre AS nombre_distrito,
            c.id_pais,
            pa.nombre AS nombre_pais,
            c.es_agente_percepcion,
            c.es_buen_contribuyente,
            c.es_agente_retenedor,
            c.afecto_rus,
            c.situacion_sunat,
            c.estado_contribuyente_sunat,
            c.observacion,
            c.estado,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_cliente = tc.id
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        LEFT JOIN gen_lista_opciones td ON c.id_tipo_documento = td.id
        LEFT JOIN gen_pais pa ON c.id_pais = pa.id
        LEFT JOIN gen_departamento dep ON c.id_departamento = dep.id
        LEFT JOIN gen_provincia prov ON c.id_provincia = prov.id
        LEFT JOIN gen_distrito dist ON c.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_cliente IS NULL OR c.id_tipo_cliente = p_id_tipo_cliente)
          AND (
                v_buscar IS NULL
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR c.codigo_interno ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY razon_social NULLS LAST, nombres NULLS LAST, id DESC
        LIMIT p_limite
        OFFSET GREATEST(p_pagina - 1, 0) * p_limite
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$; */

--ejemplo de uso listar general
select * FROM cli_listar_clientes(p_solo_activos=>False);

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