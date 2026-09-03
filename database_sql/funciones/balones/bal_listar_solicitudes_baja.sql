-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_solicitudes_baja
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
DROP FUNCTION IF EXISTS bal_listar_solicitudes_baja(p_busqueda character varying, p_limite integer, p_offset integer, p_estado_aprobacion character varying);

CREATE OR REPLACE FUNCTION bal_listar_solicitudes_baja(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_estado_aprobacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_estado VARCHAR := NULLIF(UPPER(TRIM(COALESCE(p_estado_aprobacion, ''))), '');
BEGIN
    SET TIME ZONE 'America/Lima';

    IF v_estado = 'TODOS' THEN
        v_estado := NULL;
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM bal_baja_balon bb
    INNER JOIN bal_balon b ON bb.id_balon = b.id
    LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
    LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
    WHERE bb.estado = 1
      AND (v_estado IS NULL OR bb.estado_aprobacion = v_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(mb.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(us.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            bb.id,
            bb.id_balon,
            b.codigo_balon,
            b.numero_serie,
            bb.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            bb.fecha_baja,
            bb.motivo_detalle,
            bb.id_cliente_comprador,
            cc.razon_social AS nombre_cliente_comprador,
            bb.serie_comprobante,
            bb.numero_comprobante,
            bb.monto_venta,
            bb.observacion,
            bb.id_usuario_solicita,
            us.nombre AS nombre_usuario_solicita,
            bb.estado_aprobacion,
            bb.fecha_creacion
        FROM bal_baja_balon bb
        INNER JOIN bal_balon b ON bb.id_balon = b.id
        LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
        LEFT JOIN cli_clientes cc ON bb.id_cliente_comprador = cc.id
        LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
        WHERE bb.estado = 1
          AND (v_estado IS NULL OR bb.estado_aprobacion = v_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mb.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(us.nombre, ''), p_busqueda)
          )
        -- Pendientes primero, luego más recientes
        ORDER BY
            CASE WHEN bb.estado_aprobacion = 'PENDIENTE' THEN 0 ELSE 1 END ASC,
            bb.fecha_creacion DESC,
            bb.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
