DROP FUNCTION IF EXISTS cli_listar_direcciones(
    INTEGER,
    VARCHAR,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION cli_listar_direcciones(
    p_id_cliente INTEGER DEFAULT NULL,
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM cli_direcciones d
    WHERE d.estado = 1
      AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
      AND (
          p_busqueda = ''
          OR LOWER(d.direccion) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(d.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(d.referencia, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id,
            d.id_cliente,
            COALESCE(c.razon_social, c.nombres) AS nombre_cliente,
            d.descripcion,
            d.direccion,
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
        INNER JOIN cli_clientes c ON d.id_cliente = c.id
        LEFT JOIN gen_departamento dep ON d.id_departamento = dep.id
        LEFT JOIN gen_provincia prov ON d.id_provincia = prov.id
        LEFT JOIN gen_distrito dist ON d.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc ON d.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON d.id_usuario_modificacion = um.id
        WHERE d.estado = 1
          AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
          AND (
              p_busqueda = ''
              OR LOWER(d.direccion) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(d.descripcion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(d.referencia, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY d.es_principal DESC, d.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;