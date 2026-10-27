-- Activos de la empresa: tipo, compra, sucursal, marca, serie y responsable
CREATE TABLE public.act_activos (
  id integer NOT NULL,
  id_tipo integer,
  descripcion character varying(255),
  fecha_compra date,
  importe numeric(12, 2),
  id_sucursal integer,
  marca character varying(120),
  modelo character varying(120),
  numero_serie character varying(120),
  id_trabajador_responsable integer,
  imagen_principal_ruta character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.act_activos_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.act_activos_id_seq OWNED BY public.act_activos.id;

ALTER TABLE ONLY public.act_activos
ALTER COLUMN id
SET DEFAULT nextval('public.act_activos_id_seq'::regclass);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal (id);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_id_tipo_fkey FOREIGN KEY (id_tipo) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_id_trabajador_responsable_fkey FOREIGN KEY (id_trabajador_responsable) REFERENCES public.tra_trabajadores (id);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.act_activos
ADD CONSTRAINT act_activos_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
