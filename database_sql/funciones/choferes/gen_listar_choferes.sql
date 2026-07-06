CREATE OR REPLACE FUNCTION gen_listar_choferes(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL
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
    FROM gen_chofer ch
    LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
    WHERE ch.estado = 1
      AND (p_id_cliente IS NULL OR ch.id_cliente = p_id_cliente)
      AND (
          p_busqueda = ''
          OR LOWER(ch.nombres) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(ch.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(ch.apellido_materno, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(ch.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(ch.brevete, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            ch.apellido_paterno,
            ch.apellido_materno,
            ch.nombres,
            ch.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            ch.numero_documento,
            ch.brevete,
            ch.telefono,
            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN gen_lista_opciones td ON ch.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE ch.estado = 1
          AND (p_id_cliente IS NULL OR ch.id_cliente = p_id_cliente)
          AND (
              p_busqueda = ''
              OR LOWER(ch.nombres) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(ch.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(ch.apellido_materno, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(ch.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(ch.brevete, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY ch.nombres ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
