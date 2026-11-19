-- Archivos adjuntos de una compra (factura del proveedor en PDF, foto, guía).
-- Antes no había dónde guardarlos y se mandaban por WhatsApp (chats del 23/10 y 6/11).
-- El archivo vive en storage (carpeta compras/) y en gen_archivo; aquí solo el vínculo.
CREATE TABLE public.com_compra_adjunto (
  id integer NOT NULL,
  id_compra integer NOT NULL,
  id_archivo integer NOT NULL,
  descripcion character varying(150),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.com_compra_adjunto_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.com_compra_adjunto_id_seq OWNED BY public.com_compra_adjunto.id;

ALTER TABLE ONLY public.com_compra_adjunto
ALTER COLUMN id
SET DEFAULT nextval('public.com_compra_adjunto_id_seq'::regclass);

ALTER TABLE ONLY public.com_compra_adjunto
ADD CONSTRAINT com_compra_adjunto_pkey PRIMARY KEY (id);

CREATE INDEX idx_com_compra_adjunto_compra ON public.com_compra_adjunto USING btree (id_compra)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.com_compra_adjunto
ADD CONSTRAINT com_compra_adjunto_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.com_comprobante_compra (id);

ALTER TABLE ONLY public.com_compra_adjunto
ADD CONSTRAINT com_compra_adjunto_id_archivo_fkey FOREIGN KEY (id_archivo) REFERENCES public.gen_archivo (id);
