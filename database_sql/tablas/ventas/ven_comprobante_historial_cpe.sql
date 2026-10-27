-- Historial de cambios de serie y número de comprobantes regularizados
CREATE TABLE public.ven_comprobante_historial_cpe (
  id bigint NOT NULL,
  id_comprobante integer NOT NULL,
  serie character varying(10) NOT NULL,
  numero character varying(15) NOT NULL,
  datos_originales jsonb NOT NULL,
  verificacion_sunat jsonb NOT NULL,
  serie_nueva character varying(10) NOT NULL,
  numero_nuevo character varying(15) NOT NULL,
  fecha_emision_nueva date NOT NULL,
  id_usuario_creacion integer,
  fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.ven_comprobante_historial_cpe_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_comprobante_historial_cpe_id_seq OWNED BY public.ven_comprobante_historial_cpe.id;

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ALTER COLUMN id
SET DEFAULT nextval(
  'public.ven_comprobante_historial_cpe_id_seq'::regclass
);

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ADD CONSTRAINT ven_comprobante_historial_cpe_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ADD CONSTRAINT ven_comprobante_historial_cpe_serie_numero_key UNIQUE (serie, numero);

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ADD CONSTRAINT ven_comprobante_historial_cpe_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ADD CONSTRAINT ven_comprobante_historial_cpe_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);
