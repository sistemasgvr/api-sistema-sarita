-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_etiqueta_producto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS pro_etiqueta_producto(p_id integer);

CREATE OR REPLACE FUNCTION pro_etiqueta_producto(p_id integer)
 RETURNS text
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
