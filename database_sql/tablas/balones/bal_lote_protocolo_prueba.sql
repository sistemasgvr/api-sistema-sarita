-- Pruebas y resultados de una ficha de lote y protocolo
CREATE TABLE public.bal_lote_protocolo_prueba (
  id integer NOT NULL,
  id_lote_protocolo integer NOT NULL,
  orden integer DEFAULT 0 NOT NULL,
  prueba character varying(120) NOT NULL,
  especificacion character varying(300),
  resultado character varying(120),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.bal_lote_protocolo_prueba_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_lote_protocolo_prueba_id_seq OWNED BY public.bal_lote_protocolo_prueba.id;

ALTER TABLE ONLY public.bal_lote_protocolo_prueba
ALTER COLUMN id
SET DEFAULT nextval(
  'public.bal_lote_protocolo_prueba_id_seq'::regclass
);

ALTER TABLE ONLY public.bal_lote_protocolo_prueba
ADD CONSTRAINT bal_lote_protocolo_prueba_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_lp_prueba_cab ON public.bal_lote_protocolo_prueba USING btree (id_lote_protocolo);

ALTER TABLE ONLY public.bal_lote_protocolo_prueba
ADD CONSTRAINT bal_lote_protocolo_prueba_id_lote_protocolo_fkey FOREIGN KEY (id_lote_protocolo) REFERENCES public.bal_lote_protocolo (id);

ALTER TABLE ONLY public.bal_lote_protocolo_prueba
ADD CONSTRAINT bal_lote_protocolo_prueba_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_lote_protocolo_prueba
ADD CONSTRAINT bal_lote_protocolo_prueba_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
