-- Trigger: impide cambiar la numeración de una nota de un lote de corrección
DROP FUNCTION IF EXISTS public.ven_proteger_numeracion_nota_correccion ();

CREATE OR REPLACE FUNCTION public.ven_proteger_numeracion_nota_correccion () RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.serie_original IS NOT DISTINCT FROM OLD.serie_original AND NEW.numero_original IS NOT DISTINCT FROM OLD.numero_original THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_lote l WHERE l.id=OLD.id_lote AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La referencia de la nota fiscal %-% y su comprobante original están bloqueados.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$function$;
