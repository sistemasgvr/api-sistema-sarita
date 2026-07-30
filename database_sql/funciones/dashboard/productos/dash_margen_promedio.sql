DROP FUNCTION IF EXISTS dash_margen_promedio;

CREATE OR REPLACE FUNCTION dash_margen_promedio(
    p_limite INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_margen_promedio NUMERIC(6,2) := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(AVG(
        CASE 
            WHEN cp.porcentaje_margen IS NOT NULL THEN cp.porcentaje_margen
            WHEN cp.costo_producto > 0 THEN ((cp.precio_final - cp.costo_producto) / cp.costo_producto) * 100
            ELSE 0 
        END
    ), 0) INTO v_margen_promedio
    FROM pro_catalogo_precio cp
    WHERE cp.estado = 1 AND (cp.precio_final > 0 OR cp.porcentaje_margen > 0);

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            cp.id,
            cp.nombre_item,
            p.nombre AS producto_vinculado,
            COALESCE(cp.costo_producto, 0) AS costo,
            COALESCE(cp.precio_final, 0) AS precio_venta,
            ROUND(
                COALESCE(
                    cp.porcentaje_margen,
                    CASE WHEN cp.costo_producto > 0 THEN ((cp.precio_final - cp.costo_producto) / cp.costo_producto) * 100 ELSE 0 END
                ), 2
            ) AS porcentaje_margen
        FROM pro_catalogo_precio cp
        LEFT JOIN pro_producto p ON cp.id_producto = p.id
        WHERE cp.estado = 1
        ORDER BY porcentaje_margen DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'margenPromedioPorcentaje', ROUND(v_margen_promedio, 2),
        'registros', v_registros
    );
END;
$function$;