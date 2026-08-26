DROP FUNCTION IF EXISTS gen_listar_choferes(
    INT,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION gen_listar_choferes(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
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
    LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
    WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
      AND (
          p_id_cliente IS NULL
          OR ch.id_cliente = p_id_cliente
          OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
      )
      AND (
          p_buscar = ''
          OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.id_trabajador,
            (ch.id_trabajador IS NOT NULL) AS es_chofer_empresa,
            COALESCE(tr.apellido_paterno, ch.apellido_paterno) AS apellido_paterno,
            COALESCE(tr.apellido_materno, ch.apellido_materno) AS apellido_materno,
            COALESCE(tr.nombres, ch.nombres) AS nombres,
            COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) AS id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            COALESCE(tr.numero_documento, ch.numero_documento) AS numero_documento,
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
        LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
        LEFT JOIN gen_lista_opciones td ON COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
          AND (
              p_id_cliente IS NULL
              OR ch.id_cliente = p_id_cliente
              OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
          )
          AND (
              p_buscar = ''
              OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
          )
        ORDER BY COALESCE(tr.nombres, ch.nombres) ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

