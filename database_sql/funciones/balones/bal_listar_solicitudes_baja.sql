CREATE OR REPLACE FUNCTION bal_listar_solicitudes_baja(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_estado_aprobacion VARCHAR DEFAULT 'PENDIENTE'
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
    FROM bal_baja_balon bb
    INNER JOIN bal_balon b ON bb.id_balon = b.id
    LEFT JOIN gen_lista_opciones mb ON bb.id_motivo_baja = mb.id
    LEFT JOIN auth_usuarios us ON bb.id_usuario_solicita = us.id
    WHERE bb.estado = 1
      AND bb.estado_aprobacion = COALESCE(NULLIF(TRIM(p_estado_aprobacion), ''), 'PENDIENTE')
      AND (
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(us.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
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
          AND bb.estado_aprobacion = COALESCE(NULLIF(TRIM(p_estado_aprobacion), ''), 'PENDIENTE')
          AND (
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(us.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY bb.fecha_creacion ASC, bb.id ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
