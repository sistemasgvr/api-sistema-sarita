-- Trigger: valida que el balón de un ítem de recojo esté prestado en el préstamo
DROP FUNCTION IF EXISTS public.age_validar_item_recojo ();

CREATE OR REPLACE FUNCTION public.age_validar_item_recojo () RETURNS trigger LANGUAGE plpgsql AS $function$
DECLARE v_prestamo integer;
BEGIN
    IF NEW.estado <> 1 OR NEW.id_balon IS NULL THEN RETURN NEW; END IF;
    SELECT a.id_prestamo INTO v_prestamo FROM age_actividad a
    JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
    WHERE a.id = NEW.id_actividad AND UPPER(TRIM(ta.nombre)) = 'RECOJO';
    IF NOT FOUND THEN RETURN NEW; END IF;
    PERFORM pg_advisory_xact_lock(hashtext('recojo:balon'), NEW.id_balon);
    IF NOT EXISTS (SELECT 1 FROM bal_prestamo_detalle pd
        JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
        JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE pd.id = NEW.id_prestamo_detalle AND pd.id_prestamo = v_prestamo
          AND pd.id_balon = NEW.id_balon AND pd.estado = 1 AND pd.rol = 'ENTREGADO'
          AND pd.fecha_devolucion IS NULL AND p.fecha_retorno_real IS NULL
          AND b.id_cliente_ubicacion = p.id_cliente
          AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')) THEN
        RAISE EXCEPTION 'El balón no está entregado y pendiente de devolución en este préstamo.';
    END IF;
    IF EXISTS (SELECT 1 FROM age_actividad_item ai
        JOIN age_actividad a ON a.id = ai.id_actividad
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE ai.id_balon = NEW.id_balon AND ai.estado = 1 AND ai.id <> NEW.id
          AND a.estado = 1 AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
          AND UPPER(TRIM(ea.nombre)) NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')) THEN
        RAISE EXCEPTION 'El balón ya está asignado a un recojo activo.';
    END IF;
    RETURN NEW;
END;
$function$;
