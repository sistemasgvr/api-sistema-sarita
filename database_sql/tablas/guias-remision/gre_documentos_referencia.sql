-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gre_documentos_referencia
-- Generated: 2026-09-02T21:49:01.742Z

CREATE TABLE gre_documentos_referencia (
    id integer NOT NULL,
    id_guia_remision integer NOT NULL,
    id_tipo_comprobante integer NOT NULL,
    serie character varying(10),
    numero character varying(15),
    fecha date,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_comprobante integer
);

CREATE SEQUENCE gre_documentos_referencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gre_documentos_referencia_id_seq OWNED BY public.gre_documentos_referencia.id;

ALTER TABLE gre_documentos_referencia ALTER COLUMN id SET DEFAULT nextval('public.gre_documentos_referencia_id_seq'::regclass);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_pkey PRIMARY KEY (id);

CREATE INDEX idx_gre_doc_ref_comprobante ON gre_documentos_referencia USING btree (id_comprobante);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_id_guia_remision_fkey FOREIGN KEY (id_guia_remision) REFERENCES public.gre_guia_remision(id);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_id_tipo_comprobante_fkey FOREIGN KEY (id_tipo_comprobante) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_documentos_referencia
    ADD CONSTRAINT gre_documentos_referencia_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
