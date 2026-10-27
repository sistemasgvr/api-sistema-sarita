-- Datos de la empresa y parámetros generales (tolerancia m3, PSI mínimo)
CREATE TABLE public.gen_empresa (
  id integer NOT NULL,
  ruc character varying(11) NOT NULL,
  razon_social character varying(255),
  nombre_comercial character varying(150) DEFAULT 'OXIGENO SARITA'::character varying,
  direccion character varying(255),
  telefono character varying(30),
  email character varying(150),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  tolerancia_m3_ruta_pueblo numeric(12, 4) DEFAULT 0.5000,
  psi_minimo_util numeric(12, 2) DEFAULT 100,
  id_distrito integer
);

COMMENT ON COLUMN public.gen_empresa.tolerancia_m3_ruta_pueblo IS 'Descuadre permitido (m³) al cerrar ruta pueblos. Default 0.5.';

COMMENT ON COLUMN public.gen_empresa.psi_minimo_util IS 'Si presión actual < umbral, el cilindro se considera vacío / enviar a planta. Default 100 PSI.';

CREATE SEQUENCE public.gen_empresa_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.gen_empresa_id_seq OWNED BY public.gen_empresa.id;

ALTER TABLE ONLY public.gen_empresa
ALTER COLUMN id
SET DEFAULT nextval('public.gen_empresa_id_seq'::regclass);

ALTER TABLE ONLY public.gen_empresa
ADD CONSTRAINT gen_empresa_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gen_empresa
ADD CONSTRAINT gen_empresa_ruc_key UNIQUE (ruc);

ALTER TABLE ONLY public.gen_empresa
ADD CONSTRAINT gen_empresa_id_distrito_fkey FOREIGN KEY (id_distrito) REFERENCES public.gen_distrito (id);

ALTER TABLE ONLY public.gen_empresa
ADD CONSTRAINT gen_empresa_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.gen_empresa
ADD CONSTRAINT gen_empresa_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
