-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_balones_origen_recarga
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.564Z
DROP FUNCTION IF EXISTS bal_listar_balones_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION bal_listar_balones_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric DEFAULT NULL::numeric, p_id_almacen integer DEFAULT NULL::integer, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object(
            'error', 'El producto gas es obligatorio',
            'registros', '[]'::JSON,
            'total', 0
        );
    END IF;

    WITH candidatos AS (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_producto_gas,
            p.nombre AS nombre_producto,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad AS capacidad_tipo,
            b.fecha_creacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_almacen a ON a.id = b.id_almacen
        LEFT JOIN pro_producto p ON p.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
          AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
          AND b.id_producto_gas = p_id_producto_gas
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
        -- Sin filtro por capacidad: el gas se controla en el stock global del almacén
        -- (pro_stock), no por cilindro. El balón origen es solo trazabilidad.
    )
    SELECT
        (SELECT COUNT(*) FROM candidatos),
        (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
            FROM (
                SELECT
                    id,
                    codigo_balon,
                    numero_serie,
                    id_almacen,
                    nombre_almacen,
                    id_producto_gas,
                    nombre_producto,
                    id_tipo_balon,
                    nombre_tipo_balon,
                    capacidad_tipo,
                    capacidad_disponible,
                    fecha_creacion
                FROM candidatos
                ORDER BY fecha_creacion ASC NULLS LAST, id ASC
                LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                OFFSET GREATEST(COALESCE(p_offset, 0), 0)
            ) t
        )
    INTO v_total, v_registros;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total
    );
END;
$function$
