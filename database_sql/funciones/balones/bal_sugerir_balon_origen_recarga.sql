-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_sugerir_balon_origen_recarga
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.607Z
DROP FUNCTION IF EXISTS bal_sugerir_balon_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer);

CREATE OR REPLACE FUNCTION bal_sugerir_balon_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric DEFAULT NULL::numeric, p_id_almacen integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_asignacion JSON;
    v_principal JSON;
BEGIN
    IF COALESCE(p_capacidad_requerida, 0) > 0 THEN
        v_asignacion := bal_asignar_origenes_recarga(
            p_id_producto_gas,
            p_capacidad_requerida,
            p_id_almacen,
            NULL
        );

        IF v_asignacion->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_asignacion->>'error', 'registro', NULL);
        END IF;

        v_principal := (v_asignacion->'origenes')->0;
        IF v_principal IS NULL OR v_principal::TEXT = 'null' THEN
            RETURN json_build_object(
                'error',
                'No hay balón empresa LLENO del mismo gas con stock en almacén',
                'registro',
                NULL
            );
        END IF;

        RETURN json_build_object(
            'registro', json_build_object(
                'id', (v_principal->>'id_balon')::INTEGER,
                'codigo_balon', v_principal->>'codigo_balon',
                'capacidad_disponible', (v_principal->>'capacidad_disponible')::NUMERIC,
                'capacidad_tipo', (v_principal->>'capacidad_tipo')::NUMERIC,
                'nombre_almacen', v_principal->>'nombre_almacen',
                'asignacion_etiqueta', v_asignacion->>'etiqueta',
                'origenes', v_asignacion->'origenes'
            )
        );
    END IF;

    -- Sin capacidad: primer balón con stock (FIFO)
    RETURN (
        SELECT json_build_object(
            'registro', row_to_json(t)
        )
        FROM (
            SELECT
                b.id,
                b.codigo_balon,
                bal_capacidad_disponible_balon(b.id) AS capacidad_disponible,
                tb.capacidad AS capacidad_tipo,
                a.nombre AS nombre_almacen
            FROM bal_balon b
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_almacen a ON a.id = b.id_almacen
            LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.estado = 1
              AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
              AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
              AND b.id_producto_gas = p_id_producto_gas
              AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
              AND bal_capacidad_disponible_balon(b.id) > 0
            ORDER BY b.fecha_creacion ASC NULLS LAST, b.id ASC
            LIMIT 1
        ) t
    );
END;
$function$
