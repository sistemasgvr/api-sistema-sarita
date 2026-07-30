DROP FUNCTION IF EXISTS dash_productos_registrados;

CREATE OR REPLACE FUNCTION dash_productos_registrados(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_activos BIGINT := 0;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total_activos
    FROM pro_producto
    WHERE estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT 
            p.id,
            p.codigo,
            p.codigo_barra,
            p.nombre AS producto,
            sc.nombre AS subcategoria,
            cat.nombre AS categoria,
            p.marca,
            p.presentacion,
            um.nombre AS unidad_medida,
            p.precio AS precio_venta,
            p.precio_compra,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            p.afecta_stock,
            p.fecha_creacion
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
        LEFT JOIN pro_categoria cat ON sc.id_categoria = cat.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        WHERE p.estado = 1
          AND (
              p_busqueda = ''
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'totalProductosActivos', v_total_activos,
        'registros', v_registros
    );
END;
$function$;