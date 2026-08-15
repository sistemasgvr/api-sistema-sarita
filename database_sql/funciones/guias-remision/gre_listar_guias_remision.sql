CREATE OR REPLACE FUNCTION gre_listar_guias_remision(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_guia INTEGER DEFAULT NULL,
    p_id_destinatario INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_serie VARCHAR DEFAULT NULL
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
    FROM gre_guia_remision g
    LEFT JOIN cli_clientes dest ON g.id_destinatario = dest.id
    WHERE g.estado = 1
      AND (p_id_tipo_guia IS NULL OR g.id_tipo_guia_remision = p_id_tipo_guia)
      AND (p_id_destinatario IS NULL OR g.id_destinatario = p_id_destinatario)
      AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR g.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR g.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR g.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR g.serie = TRIM(p_serie))
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(g.serie, p_busqueda)
          OR gen_texto_coincide(g.numero, p_busqueda)
          OR gen_texto_coincide(COALESCE(dest.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(dest.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.destinatario_nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.destinatario_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.remitente_nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.remitente_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.observaciones, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_tipo_guia_remision,
            tg.nombre AS nombre_tipo_guia,
            tg.descripcion AS codigo_tipo_guia,
            g.serie,
            g.numero,
            g.fecha,
            g.fecha_traslado,
            g.id_destinatario,
            COALESCE(
                NULLIF(TRIM(g.destinatario_nombre), ''),
                dest.razon_social,
                TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno))
            ) AS nombre_destinatario,
            COALESCE(
                NULLIF(TRIM(g.destinatario_documento), ''),
                dest.numero_documento
            ) AS documento_destinatario,
            g.id_motivo_traslado,
            mt.nombre AS nombre_motivo_traslado,
            mt.descripcion AS codigo_motivo_traslado,
            g.id_modalidad_traslado,
            md.nombre AS nombre_modalidad_traslado,
            md.descripcion AS codigo_modalidad_traslado,
            g.peso_bruto,
            g.numero_bultos,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            g.ticket_sunat,
            g.estado,
            g.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM gre_guia_remision_detalle d
                WHERE d.id_guia_remision = g.id AND d.estado = 1
            ) AS total_detalles,
            (
                EXISTS (
                    SELECT 1
                    FROM bal_recarga_planta rp
                    WHERE rp.estado = 1
                      AND (rp.id_guia_salida = g.id OR rp.id_guia_retorno = g.id)
                )
            ) AS vinculada_recarga_planta,
            (
                CASE
                    WHEN COALESCE(es.nombre, '') = 'ACEPTADO' THEN FALSE
                    WHEN EXISTS (
                        SELECT 1
                        FROM bal_recarga_planta rp
                        WHERE rp.estado = 1
                          AND (rp.id_guia_salida = g.id OR rp.id_guia_retorno = g.id)
                    ) THEN FALSE
                    ELSE TRUE
                END
            ) AS puede_eliminar,
            (
                CASE
                    WHEN COALESCE(es.nombre, '') = 'ACEPTADO' THEN 'aceptada SUNAT'
                    WHEN EXISTS (
                        SELECT 1
                        FROM bal_recarga_planta rp
                        WHERE rp.estado = 1
                          AND rp.id_guia_salida = g.id
                    ) THEN 'vinculada a orden de recarga'
                    WHEN EXISTS (
                        SELECT 1
                        FROM bal_recarga_planta rp
                        WHERE rp.estado = 1
                          AND rp.id_guia_retorno = g.id
                    ) THEN 'vinculada a retorno de recarga'
                    ELSE NULL
                END
            ) AS motivo_bloqueo_eliminar
        FROM gre_guia_remision g
        LEFT JOIN gen_lista_opciones tg ON g.id_tipo_guia_remision = tg.id
        LEFT JOIN gen_lista_opciones mt ON g.id_motivo_traslado = mt.id
        LEFT JOIN gen_lista_opciones md ON g.id_modalidad_traslado = md.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
        LEFT JOIN cli_clientes dest ON g.id_destinatario = dest.id
        WHERE g.estado = 1
          AND (p_id_tipo_guia IS NULL OR g.id_tipo_guia_remision = p_id_tipo_guia)
          AND (p_id_destinatario IS NULL OR g.id_destinatario = p_id_destinatario)
          AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR g.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR g.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR g.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR g.serie = TRIM(p_serie))
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(g.serie, p_busqueda)
              OR gen_texto_coincide(g.numero, p_busqueda)
              OR gen_texto_coincide(COALESCE(dest.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(dest.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.destinatario_nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.destinatario_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.remitente_nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.remitente_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.observaciones, ''), p_busqueda)
          )
        ORDER BY g.fecha DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
