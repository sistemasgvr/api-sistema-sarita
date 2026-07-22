DROP FUNCTION IF EXISTS pro_listar_productos(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN);

CREATE OR REPLACE FUNCTION pro_listar_productos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_sub_categoria INTEGER DEFAULT NULL,
    p_id_categoria INTEGER DEFAULT NULL,
    p_es_gas BOOLEAN DEFAULT NULL,
    p_es_servicio BOOLEAN DEFAULT NULL,
    p_es_alquilable BOOLEAN DEFAULT NULL,
    p_afecta_stock BOOLEAN DEFAULT NULL,
    p_solo_activos INTEGER DEFAULT 1,
    p_id_almacen INTEGER DEFAULT NULL
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
    FROM pro_producto p
    LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
    LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
    WHERE (p_solo_activos IS NULL OR p.estado = p_solo_activos)
      AND (p_id_sub_categoria IS NULL OR p.id_sub_categoria = p_id_sub_categoria)
      AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
      AND (p_es_gas IS NULL OR p.es_gas = p_es_gas)
      AND (p_es_servicio IS NULL OR p.es_servicio = p_es_servicio)
      AND (p_es_alquilable IS NULL OR p.es_alquilable = p_es_alquilable)
      AND (p_afecta_stock IS NULL OR p.afecta_stock = p_afecta_stock)
      AND (
          p_busqueda = ''
          OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.codigo_barra, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.codigo_ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.marca, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.presentacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.codigo,
            p.codigo_barra,
            p.codigo_ubicacion,
            p.nombre,
            p.id_sub_categoria,
            sc.nombre AS nombre_sub_categoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            p.marca,
            p.presentacion,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            p.afecta_stock,
            p.precio,
            p.precio_compra,
            p.precio_garantia,
            p.estado,
            EXISTS (
                SELECT 1
                FROM pro_stock s
                WHERE s.id_producto = p.id
                  AND s.estado = 1
                  AND s.stock <> 0
            ) AS tiene_stock,
            CASE
                WHEN p_id_almacen IS NULL THEN NULL
                ELSE COALESCE(st.stock, 0)
            END AS stock_actual,
            CASE
                WHEN p_id_almacen IS NULL THEN NULL
                ELSE COALESCE(st.stock_minimo, 0)
            END AS stock_minimo,
            CASE
                WHEN p_id_almacen IS NULL THEN NULL
                ELSE COALESCE(st.stock, 0) <= COALESCE(st.stock_minimo, 0)
            END AS stock_bajo,
            img.ruta AS imagen_principal_ruta,
            p.fecha_creacion,
            p.fecha_modificacion,
            p.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            p.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
        LEFT JOIN pro_categoria c ON sc.id_categoria = c.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON p.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON p.id_usuario_modificacion = um2.id
        LEFT JOIN pro_stock st
            ON st.id_producto = p.id
           AND st.estado = 1
           AND p_id_almacen IS NOT NULL
           AND st.id_almacen = p_id_almacen
        LEFT JOIN LATERAL (
            SELECT a.ruta
            FROM pro_producto_imagen pi
            INNER JOIN gen_archivo a ON a.id = pi.id_archivo
            WHERE pi.id_producto = p.id
              AND pi.estado = 1
            ORDER BY pi.es_principal DESC, pi.orden ASC, pi.id ASC
            LIMIT 1
        ) img ON TRUE
        WHERE (p_solo_activos IS NULL OR p.estado = p_solo_activos)
          AND (p_id_sub_categoria IS NULL OR p.id_sub_categoria = p_id_sub_categoria)
          AND (p_id_categoria IS NULL OR sc.id_categoria = p_id_categoria)
          AND (p_es_gas IS NULL OR p.es_gas = p_es_gas)
          AND (p_es_servicio IS NULL OR p.es_servicio = p_es_servicio)
          AND (p_es_alquilable IS NULL OR p.es_alquilable = p_es_alquilable)
          AND (p_afecta_stock IS NULL OR p.afecta_stock = p_afecta_stock)
          AND (
              p_busqueda = ''
              OR LOWER(p.codigo) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.codigo_barra, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.codigo_ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(p.nombre) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.marca, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.presentacion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(sc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
