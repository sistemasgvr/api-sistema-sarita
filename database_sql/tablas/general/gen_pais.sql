-- Países
CREATE TABLE public.gen_pais (
  id integer NOT NULL,
  nombre character varying(100) NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.gen_pais_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.gen_pais_id_seq OWNED BY public.gen_pais.id;

ALTER TABLE ONLY public.gen_pais
ALTER COLUMN id
SET DEFAULT nextval('public.gen_pais_id_seq'::regclass);

ALTER TABLE ONLY public.gen_pais
ADD CONSTRAINT gen_pais_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gen_pais
ADD CONSTRAINT gen_pais_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.gen_pais
ADD CONSTRAINT gen_pais_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
