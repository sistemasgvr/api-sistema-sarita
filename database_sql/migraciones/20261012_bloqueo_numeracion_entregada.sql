BEGIN;
ALTER TABLE ven_cpe_correccion_lote ADD COLUMN IF NOT EXISTS numeracion_bloqueada boolean NOT NULL DEFAULT false;
ALTER TABLE ven_cpe_correccion_lote ADD COLUMN IF NOT EXISTS numeracion_bloqueada_en timestamptz;
ALTER TABLE ven_cpe_correccion_lote ADD COLUMN IF NOT EXISTS motivo_bloqueo text;

CREATE OR REPLACE FUNCTION ven_proteger_numeracion_correccion() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.id_tipo_comprobante IS NOT DISTINCT FROM OLD.id_tipo_comprobante THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_reserva r JOIN ven_cpe_correccion_lote l ON l.id=r.id_lote
   WHERE r.id_comprobante=OLD.id AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La numeración de este comprobante quedó bloqueada para uso del cliente. Se conserva %-%; no se permite renumerar ni convertir su tipo.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$fn$;
DROP TRIGGER IF EXISTS ven_proteger_numeracion_correccion ON ven_comprobante;
CREATE TRIGGER ven_proteger_numeracion_correccion BEFORE UPDATE OF serie,numero,id_tipo_comprobante ON ven_comprobante
 FOR EACH ROW EXECUTE FUNCTION ven_proteger_numeracion_correccion();

CREATE OR REPLACE FUNCTION ven_proteger_numeracion_nota_correccion() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.serie_original IS NOT DISTINCT FROM OLD.serie_original AND NEW.numero_original IS NOT DISTINCT FROM OLD.numero_original THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_lote l WHERE l.id=OLD.id_lote AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La referencia de la nota fiscal %-% y su comprobante original están bloqueados.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$fn$;
DROP TRIGGER IF EXISTS ven_proteger_numeracion_nota_correccion ON ven_cpe_correccion_nota;
CREATE TRIGGER ven_proteger_numeracion_nota_correccion BEFORE UPDATE OF serie,numero,serie_original,numero_original ON ven_cpe_correccion_nota
 FOR EACH ROW EXECUTE FUNCTION ven_proteger_numeracion_nota_correccion();
COMMIT;
