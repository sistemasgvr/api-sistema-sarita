DROP FUNCTION IF EXISTS age_listar_actividades;

CREATE OR REPLACE FUNCTION age_listar_actividades(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL 
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
    FROM age_actividad act
    LEFT JOIN cli_clientes c ON act.id_cliente = c.id
    WHERE act.estado = 1
      AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
      AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
      AND (
          p_busqueda = ''
          OR LOWER(act.titulo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(act.observaciones, '')) LIKE LOWER('%' || p_busqueda || '%') 
          OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad, 
            pr.nombre AS nombre_prioridad, 
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.fecha_creacion,
            act.fecha_modificacion,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta ON act.id_tipo_actividad = ta.id
        LEFT JOIN gen_lista_opciones pr ON act.id_prioridad = pr.id 
        LEFT JOIN gen_lista_opciones ea ON act.id_estado_actividad = ea.id
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.estado = 1
          AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
          AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
          AND (
              p_busqueda = ''
              OR LOWER(act.titulo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(act.observaciones, '')) LIKE LOWER('%' || p_busqueda || '%') 
              OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY act.fecha_programada ASC, act.hora_inicio_estimada ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;