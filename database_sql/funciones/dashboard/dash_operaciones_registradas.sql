-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_operaciones_registradas
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.655Z
DROP FUNCTION IF EXISTS dash_operaciones_registradas(p_fecha date, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION dash_operaciones_registradas(p_fecha date DEFAULT CURRENT_DATE, p_limite integer DEFAULT 20, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_cant_recargas BIGINT := 0;
    v_cant_alquileres BIGINT := 0;
    v_cant_mantenimientos BIGINT := 0;
    v_total_movimientos BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_cant_recargas FROM bal_movimiento_recarga WHERE fecha_salida_almacen = p_fecha AND estado = 1;
    SELECT COUNT(*) INTO v_cant_alquileres FROM bal_alquiler WHERE fecha_inicio = p_fecha AND estado = 1;
    SELECT COUNT(*) INTO v_cant_mantenimientos FROM bal_mantenimiento WHERE fecha_ingreso = p_fecha AND estado = 1;

    v_total_movimientos := v_cant_recargas + v_cant_alquileres + v_cant_mantenimientos;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 'RECARGA' AS tipo_operacion, r.id, r.fecha_salida_almacen AS fecha, 
               COALESCE(c.razon_social, 'Mostrador') AS cliente, p.nombre AS detalle, r.capacidad AS valor
        FROM bal_movimiento_recarga r
        LEFT JOIN cli_clientes c ON r.id_cliente = c.id
        LEFT JOIN pro_producto p ON r.id_producto = p.id
        WHERE r.fecha_salida_almacen = p_fecha AND r.estado = 1

        UNION ALL

        SELECT 'ALQUILER' AS tipo_operacion, a.id, a.fecha_inicio AS fecha, 
               c.razon_social AS cliente, a.numero_alquiler AS detalle, a.total_cobrado AS valor
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON a.id_cliente = c.id
        WHERE a.fecha_inicio = p_fecha AND a.estado = 1

        UNION ALL

        SELECT 'MANTENIMIENTO' AS tipo_operacion, m.id, m.fecha_ingreso AS fecha, 
               COALESCE(c.razon_social, 'Taller') AS cliente, m.descripcion AS detalle, m.costo AS valor
        FROM bal_mantenimiento m
        LEFT JOIN cli_clientes c ON m.id_proveedor = c.id
        WHERE m.fecha_ingreso = p_fecha AND m.estado = 1

        ORDER BY fecha DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'totalMovimientos', v_total_movimientos,
        'desglose', json_build_object(
            'recargas', v_cant_recargas,
            'alquileres', v_cant_alquileres,
            'mantenimientos', v_cant_mantenimientos
        ),
        'registros', v_registros
    );
END;
$function$
