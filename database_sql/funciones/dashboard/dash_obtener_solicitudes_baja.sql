-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_obtener_solicitudes_baja
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.957Z
DROP FUNCTION IF EXISTS dash_obtener_solicitudes_baja(p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_obtener_solicitudes_baja(p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_clientes_pendientes BIGINT := 0;
    v_total_balones_pendientes BIGINT := 0;
    v_total_general BIGINT := 0;
    v_id_pendiente_cliente INTEGER;

    v_lista_balones JSON;
    v_lista_clientes JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id INTO v_id_pendiente_cliente
    FROM gen_lista_opciones
    WHERE LOWER(nombre) = 'pendiente'
    LIMIT 1;

    SELECT COUNT(*) INTO v_total_clientes_pendientes
    FROM cli_baja_cliente
    WHERE estado = 1 
      AND (v_id_pendiente_cliente IS NULL OR id_estado_aprobacion = v_id_pendiente_cliente);

    SELECT COUNT(*) INTO v_total_balones_pendientes
    FROM bal_baja_balon
    WHERE estado = 1 
      AND UPPER(estado_aprobacion) = 'PENDIENTE';

    v_total_general := v_total_clientes_pendientes + v_total_balones_pendientes;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_lista_balones
    FROM (
        SELECT
            bb.id,
            bb.id_balon,
            b.codigo_balon AS cilindro,
            COALESCE(m.nombre, bb.motivo_detalle, '—') AS motivo,
            COALESCE(u.nombre, 'Sistema') AS solicitante,
            bb.fecha_baja,
            bb.fecha_creacion::DATE AS fecha_solicitado,
            bb.monto_venta AS monto,
            bb.estado_aprobacion AS estado,
            bb.motivo_detalle
        FROM bal_baja_balon bb
        INNER JOIN bal_balon b ON bb.id_balon = b.id
        LEFT JOIN gen_lista_opciones m ON bb.id_motivo_baja = m.id
        LEFT JOIN auth_usuarios u ON bb.id_usuario_solicita = u.id
        WHERE bb.estado = 1
          AND UPPER(bb.estado_aprobacion) = 'PENDIENTE'
        ORDER BY bb.fecha_creacion DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_lista_clientes
    FROM (
        SELECT
            cb.id,
            cb.id_cliente,
            COALESCE(c.razon_social, CONCAT(c.nombres, ' ', c.apellido_paterno)) AS cliente,
            COALESCE(m.nombre, cb.motivo_detalle, '—') AS motivo,
            COALESCE(u.nombre, 'Sistema') AS solicitante,
            cb.fecha_creacion::DATE AS fecha_solicitado,
            COALESCE(est.nombre, 'PENDIENTE') AS estado,
            cb.id_estado_aprobacion,
            cb.motivo_detalle
        FROM cli_baja_cliente cb
        INNER JOIN cli_clientes c ON cb.id_cliente = c.id
        LEFT JOIN gen_lista_opciones m ON cb.id_motivo_baja = m.id
        LEFT JOIN auth_usuarios u ON cb.id_usuario_solicita = u.id
        LEFT JOIN gen_lista_opciones est ON cb.id_estado_aprobacion = est.id
        WHERE cb.estado = 1
          AND (v_id_pendiente_cliente IS NULL OR cb.id_estado_aprobacion = v_id_pendiente_cliente)
        ORDER BY cb.fecha_creacion DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'resumen', json_build_object(
            'totalGeneral', v_total_general,
            'totalClientesPendientes', v_total_clientes_pendientes,
            'totalBalonesPendientes', v_total_balones_pendientes
        ),
        'balones', json_build_object(
            'registros', v_lista_balones,
            'totalPendientes', v_total_balones_pendientes
        ),
        'clientes', json_build_object(
            'registros', v_lista_clientes,
            'totalPendientes', v_total_clientes_pendientes
        )
    );
END;
$function$;
