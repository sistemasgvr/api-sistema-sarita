DROP FUNCTION IF EXISTS cli_listar_direcciones(
    INTEGER,
    INTEGER,
    VARCHAR,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION public.cli_listar_direcciones(
    p_solo_activos integer DEFAULT NULL,
    p_id_cliente integer DEFAULT NULL,
    p_busqueda character varying DEFAULT NULL,
    p_limite integer DEFAULT 10,
    p_pagina integer DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_busqueda VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_busqueda := NULLIF(TRIM(p_busqueda), '');

    WITH filtrados AS (
        SELECT
            d.id,
            d.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            d.descripcion,
            d.direccion,
            d.id_pais,
            pa.nombre AS nombre_pais,
            d.id_departamento,
            dep.nombre AS nombre_departamento,
            d.id_provincia,
            prov.nombre AS nombre_provincia,
            d.id_distrito,
            dist.nombre AS nombre_distrito,
            d.referencia,
            d.es_principal,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion,
            d.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            d.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_direcciones d
        INNER JOIN cli_clientes c
            ON d.id_cliente = c.id
        LEFT JOIN gen_pais pa
            ON d.id_pais = pa.id
        LEFT JOIN gen_departamento dep
            ON d.id_departamento = dep.id
        LEFT JOIN gen_provincia prov
            ON d.id_provincia = prov.id
        LEFT JOIN gen_distrito dist
            ON d.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc
            ON d.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um
            ON d.id_usuario_modificacion = um.id
        WHERE
            (p_solo_activos IS NULL OR d.estado = p_solo_activos)
            AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
            AND (
                v_busqueda IS NULL
                OR d.direccion ILIKE '%' || v_busqueda || '%'
                OR COALESCE(d.descripcion, '') ILIKE '%' || v_busqueda || '%'
                OR COALESCE(d.referencia, '') ILIKE '%' || v_busqueda || '%'
            )
    ),
    total_count AS (
        SELECT COUNT(*) AS total
        FROM filtrados
    ),
    paginados AS (
        SELECT *
        FROM filtrados
        ORDER BY es_principal DESC, id DESC
        LIMIT p_limite
        OFFSET GREATEST(p_pagina - 1, 0) * p_limite
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    )
    INTO v_resultado;

    RETURN v_resultado;
END;
$function$;