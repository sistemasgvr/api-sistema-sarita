CREATE OR REPLACE FUNCTION pro_obtener_producto(p_id INTEGER)
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
            p.estado,
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
        WHERE p.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
