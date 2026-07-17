DROP FUNCTION IF EXISTS gen_listar_licencias(
    INT,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION gen_listar_licencias(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_chofer INTEGER DEFAULT NULL
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
    FROM gen_licencia gl
    WHERE (p_solo_activos IS NULL OR gl.estado = p_solo_activos)
      AND (p_id_chofer IS NULL OR gl.id_chofer = p_id_chofer)
      AND (
          p_buscar = ''
          OR LOWER(gl.codigo) LIKE LOWER('%' || p_buscar || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            gl.id,
            gl.id_chofer,
            ch.nombres AS chofer_nombres,
            ch.apellido_paterno AS chofer_apellido_paterno,
            ch.apellido_materno AS chofer_apellido_materno,
            ch.numero_documento AS chofer_numero_documento,
            gl.codigo,
            gl.id_tipo_licencia,
            tlo.nombre AS nombre_tipo_licencia,
            gl.id_categoria_licencia,
            clo.nombre AS nombre_categoria_licencia,
            gl.fecha_emision,
            gl.fecha_vencimiento,
            gl.estado,
            gl.fecha_creacion,
            gl.fecha_modificacion,
            gl.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            gl.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_licencia gl
        LEFT JOIN gen_chofer ch ON gl.id_chofer = ch.id
        LEFT JOIN gen_lista_opciones tlo ON gl.id_tipo_licencia = tlo.id
        LEFT JOIN gen_lista_opciones clo ON gl.id_categoria_licencia = clo.id
        LEFT JOIN auth_usuarios uc ON gl.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON gl.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR gl.estado = p_solo_activos)
          AND (p_id_chofer IS NULL OR gl.id_chofer = p_id_chofer)
          AND (
              p_buscar = ''
              OR LOWER(gl.codigo) LIKE LOWER('%' || p_buscar || '%')
          )
        ORDER BY gl.fecha_vencimiento DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;