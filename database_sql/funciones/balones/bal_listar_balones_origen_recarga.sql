-- Balones EMPRESA LLENOS en almacén del mismo gas, con residual >= requerido (FIFO).
CREATE OR REPLACE FUNCTION bal_listar_balones_origen_recarga(
    p_id_producto_gas INTEGER,
    p_capacidad_requerida NUMERIC DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_requerida NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object(
            'error', 'El producto gas es obligatorio',
            'registros', '[]'::JSON,
            'total', 0
        );
    END IF;

    v_requerida := COALESCE(p_capacidad_requerida, 0);

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
            bal_capacidad_disponible_balon(b.id) AS capacidad_disponible,
            b.capacidad_restante,
            b.fecha_creacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_almacen a ON a.id = b.id_almacen
        LEFT JOIN pro_producto p ON p.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') = 'EMPRESA'
          AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
          AND COALESCE(ec.nombre, '') = 'LLENO'
          AND b.id_producto_gas = p_id_producto_gas
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND bal_capacidad_disponible_balon(b.id) >= v_requerida
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
                    capacidad_restante,
                    fecha_creacion
                FROM candidatos
                ORDER BY fecha_creacion DESC NULLS LAST, id DESC
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
$function$;
