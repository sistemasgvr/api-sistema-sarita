-- Devuelve el texto 'código — nombre' de un producto
DROP FUNCTION IF EXISTS public.pro_etiqueta_producto (p_id integer);

CREATE OR REPLACE FUNCTION public.pro_etiqueta_producto (p_id integer) RETURNS text LANGUAGE sql STABLE AS $function$
    SELECT COALESCE(
        NULLIF(
            TRIM(CONCAT_WS(
                ' — ',
                NULLIF(TRIM(p.codigo), ''),
                NULLIF(TRIM(p.nombre), '')
            )),
            ''
        ),
        'Producto #' || p_id
    )
    FROM pro_producto p
    WHERE p.id = p_id;
$function$;
