-- Obtiene los datos de un producto para imprimir su etiqueta
DROP FUNCTION IF EXISTS public.pro_obtener_etiqueta_producto (p_id integer);

CREATE OR REPLACE FUNCTION public.pro_obtener_etiqueta_producto (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            p.id,
            p.codigo,
            p.nombre,
            p.codigo_barra,
            p.codigo_ubicacion,
            p.marca,
            p.presentacion,
            p.id_sub_categoria,
            sc.nombre AS nombre_sub_categoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria c ON c.id = sc.id_categoria
        WHERE p.id = p_id AND p.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
