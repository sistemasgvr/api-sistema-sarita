-- Trigger: impide más de un reparto activo para el mismo documento de salida
DROP FUNCTION IF EXISTS public.age_validar_reparto_unico ();

CREATE OR REPLACE FUNCTION public.age_validar_reparto_unico () RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
    IF NEW.estado = 1 AND NEW.id_doc_salida IS NOT NULL
       AND EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id = NEW.id_tipo_actividad AND UPPER(TRIM(nombre)) = 'REPARTO')
       AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id = NEW.id_estado_actividad AND UPPER(TRIM(nombre)) IN ('CANCELADA', 'CANCELADO')) THEN
        PERFORM pg_advisory_xact_lock(hashtext('reparto:orden'), NEW.id_doc_salida);
        IF EXISTS (SELECT 1 FROM age_actividad a
            JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_doc_salida = NEW.id_doc_salida AND a.id <> NEW.id AND a.estado = 1
              AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')) THEN
            RAISE EXCEPTION 'Esta orden de salida ya tiene un reparto asignado o realizado. Abre la actividad existente.';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;
