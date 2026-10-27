-- Envases (series de cilindro) incluidos en una ficha de lote y protocolo
CREATE TABLE public.bal_lote_protocolo_envase (
  id integer NOT NULL,
  id_lote_protocolo integer NOT NULL,
  serie_envase character varying(60) NOT NULL,
  id_balon integer,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.bal_lote_protocolo_envase_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_lote_protocolo_envase_id_seq OWNED BY public.bal_lote_protocolo_envase.id;

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ALTER COLUMN id
SET DEFAULT nextval(
  'public.bal_lote_protocolo_envase_id_seq'::regclass
);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_id_lote_protocolo_serie_envase_key UNIQUE (id_lote_protocolo, serie_envase);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_lp_envase_balon ON public.bal_lote_protocolo_envase USING btree (id_balon);

CREATE INDEX idx_bal_lp_envase_cab ON public.bal_lote_protocolo_envase USING btree (id_lote_protocolo);

CREATE INDEX idx_bal_lp_envase_serie ON public.bal_lote_protocolo_envase USING btree (serie_envase);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_id_lote_protocolo_fkey FOREIGN KEY (id_lote_protocolo) REFERENCES public.bal_lote_protocolo (id);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_lote_protocolo_envase
ADD CONSTRAINT bal_lote_protocolo_envase_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
