-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_listar_medios_pago
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_listar_medios_pago();

CREATE OR REPLACE FUNCTION fin_listar_medios_pago()
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
    SELECT COALESCE(
        json_agg(
            json_build_object('id', glo.id, 'nombre', glo.nombre)
            ORDER BY glo.id
        ),
        '[]'::json
    )
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'MedioPago';
$function$;
