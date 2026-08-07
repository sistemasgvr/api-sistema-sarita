CREATE OR REPLACE FUNCTION bal_listar_recojos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_estado_nombre VARCHAR DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_estado_nombre := NULLIF(UPPER(TRIM(p_estado_nombre)), '');

    SELECT COUNT(*)
    INTO v_total
    FROM bal_recojo r
    LEFT JOIN cli_clientes c ON c.id = r.id_cliente
    LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
      AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
      AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            r.id_prestamo,
            pr.numero_prestamo,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_recojo_detalle rd
                WHERE rd.id_recojo = r.id AND rd.estado = 1
            ) AS total_detalles,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        WHERE r.estado = 1
          AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
          AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
          AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
          )
        ORDER BY r.fecha_programada DESC NULLS LAST, r.id DESC
        LIMIT p_limite
        OFFSET COALESCE(p_offset, 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
