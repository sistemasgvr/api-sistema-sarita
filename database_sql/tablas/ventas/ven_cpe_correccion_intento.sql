-- Intentos de envío de notas de un lote de corrección de comprobantes
CREATE TABLE public.ven_cpe_correccion_intento (
  id bigint NOT NULL,
  id_nota bigint NOT NULL,
  iniciado_en timestamp with time zone DEFAULT now() NOT NULL,
  terminado_en timestamp with time zone,
  resultado jsonb
);

CREATE SEQUENCE public.ven_cpe_correccion_intento_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_cpe_correccion_intento_id_seq OWNED BY public.ven_cpe_correccion_intento.id;

ALTER TABLE ONLY public.ven_cpe_correccion_intento
ALTER COLUMN id
SET DEFAULT nextval(
  'public.ven_cpe_correccion_intento_id_seq'::regclass
);

ALTER TABLE ONLY public.ven_cpe_correccion_intento
ADD CONSTRAINT ven_cpe_correccion_intento_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ven_cpe_correccion_intento
ADD CONSTRAINT ven_cpe_correccion_intento_id_nota_fkey FOREIGN KEY (id_nota) REFERENCES public.ven_cpe_correccion_nota (id);
