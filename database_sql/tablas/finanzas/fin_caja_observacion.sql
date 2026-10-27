-- Observaciones de caja por fecha
CREATE TABLE public.fin_caja_observacion (
  id integer NOT NULL,
  fecha date NOT NULL,
  texto character varying(1000) NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.fin_caja_observacion_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.fin_caja_observacion_id_seq OWNED BY public.fin_caja_observacion.id;

ALTER TABLE ONLY public.fin_caja_observacion
ALTER COLUMN id
SET DEFAULT nextval('public.fin_caja_observacion_id_seq'::regclass);

ALTER TABLE ONLY public.fin_caja_observacion
ADD CONSTRAINT fin_caja_observacion_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_caja_observacion_fecha ON public.fin_caja_observacion USING btree (fecha)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.fin_caja_observacion
ADD CONSTRAINT fin_caja_observacion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.fin_caja_observacion
ADD CONSTRAINT fin_caja_observacion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
