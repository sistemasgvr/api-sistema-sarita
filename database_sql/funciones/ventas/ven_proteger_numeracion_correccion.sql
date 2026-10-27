-- Trigger: impide cambiar serie, número o tipo de un comprobante con corrección reservada
DROP FUNCTION IF EXISTS public.ven_proteger_numeracion_correccion ();

CREATE OR REPLACE FUNCTION public.ven_proteger_numeracion_correccion () RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.id_tipo_comprobante IS NOT DISTINCT FROM OLD.id_tipo_comprobante THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_reserva r JOIN ven_cpe_correccion_lote l ON l.id=r.id_lote
   WHERE r.id_comprobante=OLD.id AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La numeración de este comprobante quedó bloqueada para uso del cliente. Se conserva %-%; no se permite renumerar ni convertir su tipo.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$function$;
