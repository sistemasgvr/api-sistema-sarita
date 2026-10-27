-- Obtiene los datos de un balón para imprimir su etiqueta
DROP FUNCTION IF EXISTS public.bal_obtener_etiqueta_balon (p_id integer);

CREATE OR REPLACE FUNCTION public.bal_obtener_etiqueta_balon (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.fecha_fabricacion,
            b.anio_fabricacion,
            b.mes_fabricacion,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.fecha_ultima_prueba_hidrostatica,
            b.fecha_proxima_prueba_hidrostatica
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones mc ON mc.id = b.id_marca_cilindro
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
        LEFT JOIN pro_producto pg ON pg.id = b.id_producto_gas
        WHERE b.id = p_id AND b.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
