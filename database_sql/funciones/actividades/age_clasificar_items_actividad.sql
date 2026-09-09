-- Function: age_clasificar_items_actividad
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql

DROP FUNCTION IF EXISTS age_clasificar_items_actividad(integer);

CREATE OR REPLACE FUNCTION age_clasificar_items_actividad(p_id_actividad integer)
RETURNS TABLE (id_item integer, clase character varying)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        ai.id,
        CASE
            WHEN ai.id_balon IS NOT NULL THEN 'CILINDRO'
            WHEN ai.id_producto IS NOT NULL AND EXISTS (
                SELECT 1
                FROM age_actividad_item c
                JOIN bal_balon b ON b.id = c.id_balon
                WHERE c.id_actividad = ai.id_actividad
                  AND c.estado = 1
                  AND c.id_balon IS NOT NULL
                  AND b.id_producto_gas = ai.id_producto
            ) THEN 'GAS'
            ELSE 'ACCESORIO'
        END::VARCHAR
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id_actividad
      AND ai.estado = 1;
$function$;
