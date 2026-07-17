CREATE OR REPLACE FUNCTION pro_obtener_catalogo_precio(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
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
        WHERE cp.id = p_id AND cp.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
