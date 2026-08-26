DROP FUNCTION IF EXISTS age_listar_actividades(VARCHAR, INTEGER, INTEGER, DATE, DATE, INTEGER, INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION age_listar_actividades(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_tipo INTEGER DEFAULT NULL,
    p_id_prioridad INTEGER DEFAULT NULL,
    p_sin_responsable BOOLEAN DEFAULT NULL
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
      AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
      AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
       AND (p_sin_responsable IS NULL OR (
           (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
           OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
       ))
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(act.titulo, p_busqueda)
          OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
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
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_guia_remision,
            gr.serie AS serie_guia_remision,
            gr.numero AS numero_guia_remision,
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
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN gre_guia_remision gr ON act.id_guia_remision = gr.id
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.estado = 1
          AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
          AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
          AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
          AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
          AND (p_sin_responsable IS NULL OR (
              (p_sin_responsable AND act.id_usuario_responsable IS NULL AND act.id_chofer_responsable IS NULL)
              OR (NOT p_sin_responsable AND (act.id_usuario_responsable IS NOT NULL OR act.id_chofer_responsable IS NOT NULL))
          ))
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(act.titulo, p_busqueda)
              OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY
            CASE
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('PENDIENTE', 'PROGRAMADA') THEN 0
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('CANCELADA', 'CANCELADO') THEN 2
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA' THEN 3
                ELSE 1
            END ASC,
            act.fecha_programada DESC,
            act.hora_inicio_estimada DESC NULLS LAST,
            act.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
