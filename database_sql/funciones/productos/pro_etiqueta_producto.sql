-- Etiqueta legible de producto para mensajes de error (código — nombre).
CREATE OR REPLACE FUNCTION pro_etiqueta_producto(p_id INTEGER)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $function$
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
