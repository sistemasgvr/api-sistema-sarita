BEGIN;
CREATE TABLE IF NOT EXISTS ven_cpe_correccion_lote (
  id uuid PRIMARY KEY,
  motivo text NOT NULL,
  estado varchar(40) NOT NULL DEFAULT 'PREPARADO',
  fecha_fiscal date NOT NULL,
  plan jsonb NOT NULL,
  creado_en timestamptz NOT NULL DEFAULT NOW(),
  actualizado_en timestamptz NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS ven_cpe_correccion_nota (
  id bigserial PRIMARY KEY,
  id_lote uuid NOT NULL REFERENCES ven_cpe_correccion_lote(id),
  id_empresa integer NOT NULL REFERENCES gen_empresa(id),
  id_comprobante_original integer NOT NULL REFERENCES ven_comprobante(id),
  serie_original varchar(4) NOT NULL,
  numero_original varchar(8) NOT NULL,
  serie varchar(4) NOT NULL CHECK (serie IN ('FC02','BC02')),
  numero integer NOT NULL CHECK (numero>0),
  importe numeric(18,2) NOT NULL CHECK (importe>0),
  estado varchar(40) NOT NULL DEFAULT 'PREPARADO',
  payload jsonb NOT NULL,
  xml_firmado text,
  hash_documento text,
  cdr_respuesta jsonb,
  verificacion_original jsonb NOT NULL,
  datos_originales jsonb NOT NULL,
  creado_en timestamptz NOT NULL DEFAULT NOW(),
  actualizado_en timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE(id_empresa,serie,numero),
  UNIQUE(id_lote,id_comprobante_original)
);
CREATE INDEX IF NOT EXISTS ix_correccion_nota_venta ON ven_cpe_correccion_nota(id_comprobante_original);
CREATE TABLE IF NOT EXISTS ven_cpe_correccion_intento (
  id bigserial PRIMARY KEY,
  id_nota bigint NOT NULL REFERENCES ven_cpe_correccion_nota(id),
  iniciado_en timestamptz NOT NULL DEFAULT NOW(),
  terminado_en timestamptz,
  resultado jsonb
);

-- Las series reservadas para estas NC no pueden reutilizarse al crear una NC normal.
DO $reserve$
DECLARE definition text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO STRICT definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='ven_obtener_siguiente_numero';
  definition:=replace(definition,chr(13)||chr(10),chr(10));
  IF position('ven_cpe_correccion_nota' IN definition)=0 THEN
    definition:=replace(definition,'    v_siguiente := LPAD',
      '    IF v_serie IN (''FC02'',''BC02'') THEN' || chr(10) ||
      '        SELECT GREATEST(v_ultimo,COALESCE(MAX(numero),0)) INTO v_ultimo FROM ven_cpe_correccion_nota WHERE serie=v_serie;' || chr(10) ||
      '    END IF;' || chr(10) || '    v_siguiente := LPAD');
    IF position('ven_cpe_correccion_nota' IN definition)=0 THEN RAISE EXCEPTION 'No se pudo reservar la numeración NC'; END IF;
    EXECUTE definition;
  END IF;
END;
$reserve$;
COMMIT;
