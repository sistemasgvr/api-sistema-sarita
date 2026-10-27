-- Sucursales con código, dirección y ubigeo
CREATE TABLE public.gen_sucursal (
  id integer NOT NULL,
  codigo character varying(20) NOT NULL,
  nombre character varying(150) NOT NULL,
  direccion character varying(255),
  id_departamento integer,
  id_provincia integer,
  id_distrito integer,
  telefono character varying(30),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.gen_sucursal_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.gen_sucursal_id_seq OWNED BY public.gen_sucursal.id;

ALTER TABLE ONLY public.gen_sucursal
ALTER COLUMN id
SET DEFAULT nextval('public.gen_sucursal_id_seq'::regclass);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_codigo_key UNIQUE (codigo);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.gen_departamento (id);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_id_distrito_fkey FOREIGN KEY (id_distrito) REFERENCES public.gen_distrito (id);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES public.gen_provincia (id);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.gen_sucursal
ADD CONSTRAINT gen_sucursal_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
