-- Historial de pruebas hidrostáticas de balones con vigencia y certificado
CREATE TABLE public.bal_balon_ph_historial (
  id integer NOT NULL,
  id_balon integer NOT NULL,
  fecha_prueba date NOT NULL,
  vigencia_anios integer DEFAULT 5 NOT NULL,
  fecha_proxima date,
  id_organo_inspector integer,
  organo_inspector_no_aplica boolean DEFAULT FALSE NOT NULL,
  numero_certificado character varying(50),
  id_mantenimiento integer,
  id_movimiento_recarga integer,
  es_vigente boolean DEFAULT TRUE NOT NULL,
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_doc_salida integer
);

CREATE SEQUENCE public.bal_balon_ph_historial_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_balon_ph_historial_id_seq OWNED BY public.bal_balon_ph_historial.id;

ALTER TABLE ONLY public.bal_balon_ph_historial
ALTER COLUMN id
SET DEFAULT nextval('public.bal_balon_ph_historial_id_seq'::regclass);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_balon_ph_historial_balon ON public.bal_balon_ph_historial USING btree (id_balon);

CREATE INDEX idx_bal_balon_ph_historial_vigente ON public.bal_balon_ph_historial USING btree (id_balon, es_vigente)
WHERE
  (es_vigente = TRUE);

CREATE UNIQUE INDEX uq_bal_ph_historial_doc_salida_balon ON public.bal_balon_ph_historial USING btree (id_doc_salida, id_balon)
WHERE
  (
    (id_doc_salida IS NOT NULL)
    AND (estado = 1)
  );

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_mantenimiento_fkey FOREIGN KEY (id_mantenimiento) REFERENCES public.bal_mantenimiento (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_movimiento_recarga_fkey FOREIGN KEY (id_movimiento_recarga) REFERENCES public.bal_movimiento_recarga (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_organo_inspector_fkey FOREIGN KEY (id_organo_inspector) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_balon_ph_historial
ADD CONSTRAINT bal_balon_ph_historial_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
