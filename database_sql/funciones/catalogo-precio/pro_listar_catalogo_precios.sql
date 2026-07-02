CREATE OR REPLACE FUNCTION pro_listar_catalogo_precios(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_catalogo INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_periodo VARCHAR DEFAULT NULL
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
    FROM pro_catalogo_precio cp
    LEFT JOIN gen_lista_opciones tc ON cp.id_tipo_catalogo = tc.id
    LEFT JOIN pro_producto p ON cp.id_producto = p.id
    LEFT JOIN cli_clientes prov ON cp.id_proveedor = prov.id
    WHERE cp.estado = 1
      AND (p_id_tipo_catalogo IS NULL OR cp.id_tipo_catalogo = p_id_tipo_catalogo)
      AND (p_id_producto IS NULL OR cp.id_producto = p_id_producto)
      AND (p_id_proveedor IS NULL OR cp.id_proveedor = p_id_proveedor)
      AND (p_periodo IS NULL OR cp.periodo = p_periodo)
      AND (
          p_busqueda = ''
          OR LOWER(cp.nombre_item) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cp.periodo, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cp.clasificacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cp.modelo, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(prov.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cp.id,
            cp.id_tipo_catalogo,
            tc.nombre AS nombre_tipo_catalogo,
            cp.periodo,
            cp.nombre_item,
            cp.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            cp.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            cp.id_proveedor,
            COALESCE(prov.razon_social, prov.nombres) AS nombre_proveedor,
            cp.clasificacion,
            cp.modelo,
            cp.capacidad,
            cp.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            cp.descripcion_presentacion,
            cp.costo_producto,
            cp.costo_flete,
            cp.porcentaje_margen,
            cp.precio_final,
            cp.precio_garantia,
            cp.estado,
            cp.fecha_creacion,
            cp.fecha_modificacion,
            cp.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cp.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_catalogo_precio cp
        LEFT JOIN gen_lista_opciones tc ON cp.id_tipo_catalogo = tc.id
        LEFT JOIN pro_producto p ON cp.id_producto = p.id
        LEFT JOIN bal_tipo_balon tb ON cp.id_tipo_balon = tb.id
        LEFT JOIN cli_clientes prov ON cp.id_proveedor = prov.id
        LEFT JOIN gen_lista_opciones um ON cp.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON cp.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON cp.id_usuario_modificacion = um2.id
        WHERE cp.estado = 1
          AND (p_id_tipo_catalogo IS NULL OR cp.id_tipo_catalogo = p_id_tipo_catalogo)
          AND (p_id_producto IS NULL OR cp.id_producto = p_id_producto)
          AND (p_id_proveedor IS NULL OR cp.id_proveedor = p_id_proveedor)
          AND (p_periodo IS NULL OR cp.periodo = p_periodo)
          AND (
              p_busqueda = ''
              OR LOWER(cp.nombre_item) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cp.periodo, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cp.clasificacion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cp.modelo, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(prov.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY cp.periodo DESC NULLS LAST, cp.nombre_item ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
