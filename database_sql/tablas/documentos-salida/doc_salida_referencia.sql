-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: doc_salida_referencia
-- Generated: 2026-09-03T16:49:07.048Z

CREATE TABLE doc_salida_referencia (
    id integer NOT NULL,
    id_doc_salida integer NOT NULL,
    id_tipo_comprobante integer NOT NULL,
    id_comprobante integer,
    serie character varying(10),
    numero character varying(15),
    fecha date,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp without time zone
);

CREATE SEQUENCE doc_salida_referencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE doc_salida_referencia_id_seq OWNED BY public.doc_salida_referencia.id;

ALTER TABLE doc_salida_referencia ALTER COLUMN id SET DEFAULT nextval('public.doc_salida_referencia_id_seq'::regclass);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_pkey PRIMARY KEY (id);

CREATE INDEX idx_doc_salida_referencia_doc ON public.doc_salida_referencia USING btree (id_doc_salida);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida(id);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_id_tipo_comprobante_fkey FOREIGN KEY (id_tipo_comprobante) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_salida_referencia
    ADD CONSTRAINT doc_salida_referencia_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
