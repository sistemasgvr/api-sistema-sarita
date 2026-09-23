-- Function: age_listar_actividades
-- Source: migraciones/20260908_age_id_doc_salida_y_ordenes_disponibles.sql

CREATE OR REPLACE FUNCTION age_listar_actividades(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_fecha_desde date DEFAULT NULL::date,
    p_fecha_hasta date DEFAULT NULL::date,
    p_id_estado integer DEFAULT NULL::integer,
    p_id_tipo integer DEFAULT NULL::integer,
    p_id_prioridad integer DEFAULT NULL::integer,
    p_sin_responsable boolean DEFAULT NULL::boolean
)
RETURNS json
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
            COALESCE(NULLIF(TRIM(c.razon_social), ''), NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.numero_documento) AS razon_social_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            ch.id AS id_chofer_responsable,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer_responsable,
            COALESCE(act.id_comprobante, ds.id_venta) AS id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            cc.id AS id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
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
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN LATERAL (
            SELECT ch0.* FROM gen_chofer ch0
            WHERE ch0.id = COALESCE(act.id_chofer_responsable, ds.id_chofer)
               OR (act.id_chofer_responsable IS NULL AND ds.id_chofer IS NULL AND ch0.id_trabajador = tr.id AND ch0.estado = 1)
            ORDER BY ch0.id LIMIT 1
        ) ch ON TRUE
        LEFT JOIN ven_comprobante vc ON vc.id = COALESCE(act.id_comprobante, ds.id_venta)
        LEFT JOIN LATERAL (
            SELECT compra.id, compra.serie, compra.numero FROM com_comprobante_compra compra
            WHERE compra.id = ds.id_comprobante_compra
               OR (ds.id_comprobante_compra IS NULL AND compra.id_doc_salida = ds.id AND compra.estado = 1)
            ORDER BY compra.id DESC LIMIT 1
        ) cc ON TRUE
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
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

-- =============================================================================

