-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_demanda_gases
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.955Z
DROP FUNCTION IF EXISTS dash_demanda_gases(p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION dash_demanda_gases(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Antes: dos sentencias SELECT separadas reutilizaban el mismo WITH ("detalle_gas"),
    -- pero un CTE solo existe dentro de la sentencia que lo declara; la segunda sentencia
    -- fallaba en tiempo de ejecución con "relation detalle_gas does not exist" y la
    -- función nunca llegó a devolver datos. Se une todo en una sola sentencia.
    WITH detalle_gas AS (
        SELECT
            p.id AS id_producto,
            p.nombre,
            SUM(vcd.cantidad) AS cantidad
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        JOIN pro_producto p ON p.id = vcd.id_producto
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND (p_fecha_desde IS NULL OR vc.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR vc.fecha <= p_fecha_hasta)
        GROUP BY p.id, p.nombre
    ),
    totales AS (
        SELECT COALESCE(SUM(cantidad), 0) AS total FROM detalle_gas
    )
    SELECT json_build_object(
        'totalCantidad', (SELECT total FROM totales),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', d.id_producto,
                'producto', d.nombre,
                'cantidad', d.cantidad,
                'porcentaje', CASE WHEN t.total > 0 THEN ROUND(d.cantidad / t.total * 100, 2) ELSE 0 END
            )
            ORDER BY d.cantidad DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM detalle_gas d
    CROSS JOIN totales t;

    RETURN v_result;
END;
$function$;
