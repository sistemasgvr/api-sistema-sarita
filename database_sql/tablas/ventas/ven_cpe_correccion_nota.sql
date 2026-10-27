-- Notas emitidas en un lote de corrección sobre comprobantes originales
CREATE TABLE public.ven_cpe_correccion_nota (
  id bigint NOT NULL,
  id_lote uuid NOT NULL,
  id_empresa integer NOT NULL,
  id_comprobante_original integer NOT NULL,
  serie_original character varying(4) NOT NULL,
  numero_original character varying(8) NOT NULL,
  serie character varying(4) NOT NULL,
  numero integer NOT NULL,
  importe numeric(18, 2) NOT NULL,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  payload jsonb NOT NULL,
  xml_firmado text,
  hash_documento text,
  cdr_respuesta jsonb,
  verificacion_original jsonb NOT NULL,
  datos_originales jsonb NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_cpe_correccion_nota_importe_check CHECK ((importe > (0)::numeric)),
  CONSTRAINT ven_cpe_correccion_nota_numero_check CHECK ((numero > 0)),
  CONSTRAINT ven_cpe_correccion_nota_serie_check CHECK (
    (
      (serie)::text = ANY (
        (
          ARRAY[
            'FC02'::character varying,
            'BC02'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

CREATE SEQUENCE public.ven_cpe_correccion_nota_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_cpe_correccion_nota_id_seq OWNED BY public.ven_cpe_correccion_nota.id;

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ALTER COLUMN id
SET DEFAULT nextval('public.ven_cpe_correccion_nota_id_seq'::regclass);

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_id_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_id_lote_id_comprobante_original_key UNIQUE (id_lote, id_comprobante_original);

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_pkey PRIMARY KEY (id);

CREATE INDEX ix_correccion_nota_venta ON public.ven_cpe_correccion_nota USING btree (id_comprobante_original);

CREATE TRIGGER ven_proteger_numeracion_nota_correccion
BEFORE UPDATE OF serie,
numero,
serie_original,
numero_original ON public.ven_cpe_correccion_nota FOR EACH ROW
EXECUTE FUNCTION public.ven_proteger_numeracion_nota_correccion ();

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_id_comprobante_original_fkey FOREIGN KEY (id_comprobante_original) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ADD CONSTRAINT ven_cpe_correccion_nota_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
