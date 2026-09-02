-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_rutas_pueblo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.576Z
DROP FUNCTION IF EXISTS bal_listar_rutas_pueblo(p_busqueda character varying, p_limite integer, p_offset integer, p_estado_nombre character varying, p_id_almacen integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION bal_listar_rutas_pueblo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_estado_nombre character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
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
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_almacen a ON a.id = r.id_almacen
    LEFT JOIN auth_usuarios u ON u.id = r.id_usuario_responsable
    LEFT JOIN gen_chofer ch ON ch.id = r.id_chofer
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND (p_id_almacen IS NULL OR r.id_almacen = p_id_almacen)
      AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
      AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(u.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno), ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.id_almacen,
            a.nombre AS nombre_almacen,
            r.id_usuario_responsable,
            u.nombre AS nombre_usuario_responsable,
            r.id_chofer,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer,
            r.factor_lb_m3,
            r.tolerancia_m3,
            r.m3_reportado_ventas,
            r.m3_calculado,
            r.descuadre_m3,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.observacion,
            (
                SELECT COUNT(*)::INT
                FROM bal_ruta_pueblo_detalle d
                WHERE d.id_ruta_pueblo = r.id AND d.estado = 1
            ) AS total_cilindros,
            (
                SELECT COUNT(*)::INT
                FROM bal_ruta_pueblo_detalle d
                WHERE d.id_ruta_pueblo = r.id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
            ) AS total_retornados
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_almacen a ON a.id = r.id_almacen
        LEFT JOIN auth_usuarios u ON u.id = r.id_usuario_responsable
        LEFT JOIN gen_chofer ch ON ch.id = r.id_chofer
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.estado = 1
          AND (p_id_almacen IS NULL OR r.id_almacen = p_id_almacen)
          AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
          AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(u.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno), ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
          )
        ORDER BY r.fecha DESC, r.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 10), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
