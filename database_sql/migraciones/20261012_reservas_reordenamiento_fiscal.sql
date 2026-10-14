BEGIN;
CREATE TABLE IF NOT EXISTS ven_cpe_correccion_reserva (
  serie varchar(4) NOT NULL CHECK (serie IN ('F002','B002')),
  numero integer NOT NULL CHECK (numero>0),
  id_lote uuid NOT NULL REFERENCES ven_cpe_correccion_lote(id),
  id_comprobante integer NOT NULL REFERENCES ven_comprobante(id),
  creado_en timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (serie,numero), UNIQUE(id_lote,id_comprobante)
);
CREATE TABLE IF NOT EXISTS ven_cpe_correccion_reemplazo (
  id_lote uuid NOT NULL REFERENCES ven_cpe_correccion_lote(id),
  id_comprobante integer NOT NULL REFERENCES ven_comprobante(id),
  serie varchar(4) NOT NULL,numero varchar(8) NOT NULL,
  payload jsonb NOT NULL,xml_firmado text,respuesta jsonb,
  estado varchar(40) NOT NULL DEFAULT 'PREPARADO',
  intentos integer NOT NULL DEFAULT 0,
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id_lote,id_comprobante),UNIQUE(serie,numero)
);
-- Reservar números fiscales no modifica ventas, saldos ni stock.
DO $reserve$
DECLARE definition text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO STRICT definition FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='ven_obtener_siguiente_numero';
 definition:=replace(definition,chr(13)||chr(10),chr(10));
 IF position('ven_cpe_correccion_reserva' IN definition)=0 THEN
  definition:=replace(definition,'    v_siguiente := LPAD',
   '    IF v_serie IN (''F002'',''B002'') THEN' || chr(10) ||
   '        SELECT GREATEST(v_ultimo,COALESCE(MAX(numero),0)) INTO v_ultimo FROM ven_cpe_correccion_reserva WHERE serie=v_serie;' || chr(10) ||
   '    END IF;' || chr(10) || '    v_siguiente := LPAD');
  IF position('ven_cpe_correccion_reserva' IN definition)=0 THEN RAISE EXCEPTION 'No se pudo reservar el rango fiscal'; END IF;
  EXECUTE definition;
 END IF;
END;
$reserve$;
COMMIT;
