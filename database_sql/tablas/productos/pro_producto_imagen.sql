-- Imágenes de productos con orden e indicador de principal
CREATE TABLE public.pro_producto_imagen (
  id integer NOT NULL,
  id_producto integer NOT NULL,
  id_archivo integer NOT NULL,
  orden integer DEFAULT 0 NOT NULL,
  es_principal boolean DEFAULT FALSE NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.pro_producto_imagen_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.pro_producto_imagen_id_seq OWNED BY public.pro_producto_imagen.id;

ALTER TABLE ONLY public.pro_producto_imagen
ALTER COLUMN id
SET DEFAULT nextval('public.pro_producto_imagen_id_seq'::regclass);

ALTER TABLE ONLY public.pro_producto_imagen
ADD CONSTRAINT pro_producto_imagen_pkey PRIMARY KEY (id);

CREATE INDEX idx_pro_producto_imagen_archivo ON public.pro_producto_imagen USING btree (id_archivo)
WHERE
  (estado = 1);

CREATE INDEX idx_pro_producto_imagen_producto ON public.pro_producto_imagen USING btree (id_producto)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.pro_producto_imagen
ADD CONSTRAINT pro_producto_imagen_id_archivo_fkey FOREIGN KEY (id_archivo) REFERENCES public.gen_archivo (id);

ALTER TABLE ONLY public.pro_producto_imagen
ADD CONSTRAINT pro_producto_imagen_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.pro_producto_imagen
ADD CONSTRAINT pro_producto_imagen_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.pro_producto_imagen
ADD CONSTRAINT pro_producto_imagen_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
