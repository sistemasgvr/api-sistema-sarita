-- ⚠️ NO EJECUTAR sin revisión del usuario (apply-migration.js) — solo dejar el archivo listo.
--
-- Agrega el parámetro p_solo_activos a ven_listar_comprobantes para poder ver
-- comprobantes anulados/eliminados desde el listado (hoy hardcodea WHERE c.estado = 1,
-- sin forma de override). Sigue el mismo patrón usado en gen_listar_choferes:
-- p_solo_activos IS NULL => todos (activos e inactivos), 1 => solo activos,
-- 0 => solo inactivos. Default 1 para no cambiar el comportamiento de ningún
-- llamador existente que no pase el parámetro.
--
-- Parámetro nuevo al final (posición 11) — la capa NestJS usa argumentos posicionales
-- (DatabaseService.callFunctionJson), así que los llamadores actuales no se rompen.

-- La versión en vivo hoy tiene 10 parámetros (sin p_solo_activos); hay que
-- eliminarla explícitamente porque CREATE OR REPLACE con un parámetro nuevo
-- crea un overload en paralelo en vez de reemplazarla.
DROP FUNCTION IF EXISTS ven_listar_comprobantes(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_comprobante integer, p_id_cliente integer, p_id_estado integer, p_id_estado_sunat integer, p_fecha_desde date, p_fecha_hasta date, p_serie character varying);

CREATE OR REPLACE FUNCTION ven_listar_comprobantes(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_comprobante integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_estado_sunat integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_serie character varying DEFAULT NULL::character varying, p_solo_activos integer DEFAULT 1)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_busqueda TEXT;
    v_busqueda_norm TEXT;
    v_busqueda_sin_guion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_busqueda := TRIM(COALESCE(p_busqueda, ''));
    v_busqueda_norm := LOWER(REPLACE(REPLACE(v_busqueda, ' ', ''), '/', '-'));
    v_busqueda_sin_guion := REPLACE(v_busqueda_norm, '-', '');

    SELECT COUNT(*) INTO v_total
    FROM ven_comprobante c
    LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
    LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
      AND (
          v_busqueda = ''
          OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
          OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR gen_texto_coincide(COALESCE(cl.razon_social, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            cd.id AS id_comprobante_destino,
            cd.serie AS serie_comprobante_destino,
            cd.numero AS numero_comprobante_destino,
            tc_destino.descripcion AS codigo_tipo_comprobante_destino,
            tc_destino.nombre AS nombre_tipo_comprobante_destino,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.total_importe,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            (act.id IS NOT NULL) AS tiene_actividad,
            c.estado,
            c.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS total_detalles
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN LATERAL (
            SELECT d.id, d.serie, d.numero, d.id_tipo_comprobante
            FROM ven_comprobante d
            WHERE d.id_comprobante_origen = c.id AND d.estado = 1
            ORDER BY d.id DESC
            LIMIT 1
        ) cd ON TRUE
        LEFT JOIN gen_lista_opciones tc_destino ON cd.id_tipo_comprobante = tc_destino.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_comprobante = c.id
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
          AND (
              v_busqueda = ''
              OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
              OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR gen_texto_coincide(COALESCE(cl.razon_social, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
