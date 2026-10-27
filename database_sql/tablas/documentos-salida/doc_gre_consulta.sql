-- Respuestas de consulta de un intento de envío de guía de remisión
CREATE TABLE public.doc_gre_consulta (
  id bigint NOT NULL,
  id_intento bigint NOT NULL,
  respuesta jsonb NOT NULL,
  creado timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.doc_gre_consulta_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.doc_gre_consulta_id_seq OWNED BY public.doc_gre_consulta.id;

ALTER TABLE ONLY public.doc_gre_consulta
ALTER COLUMN id
SET DEFAULT nextval('public.doc_gre_consulta_id_seq'::regclass);

ALTER TABLE ONLY public.doc_gre_consulta
ADD CONSTRAINT doc_gre_consulta_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.doc_gre_consulta
ADD CONSTRAINT doc_gre_consulta_id_intento_fkey FOREIGN KEY (id_intento) REFERENCES public.doc_gre_intento (id);
