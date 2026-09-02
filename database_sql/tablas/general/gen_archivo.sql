-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_archivo
-- Generated: 2026-09-02T21:46:22.587Z

CREATE TABLE gen_archivo (
    id integer NOT NULL,
    nombre_original character varying(255) NOT NULL,
    nombre_almacenado character varying(255) NOT NULL,
    ruta character varying(500) NOT NULL,
    bucket character varying(100) NOT NULL,
    mime_type character varying(150),
    extension character varying(20),
    tamanio_bytes bigint,
    id_empresa integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_archivo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_archivo_id_seq OWNED BY public.gen_archivo.id;

ALTER TABLE gen_archivo ALTER COLUMN id SET DEFAULT nextval('public.gen_archivo_id_seq'::regclass);

ALTER TABLE gen_archivo
    ADD CONSTRAINT gen_archivo_bucket_ruta_key UNIQUE (bucket, ruta);

ALTER TABLE gen_archivo
    ADD CONSTRAINT gen_archivo_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_archivo_empresa ON gen_archivo USING btree (id_empresa) WHERE (estado = 1);

CREATE INDEX idx_gen_archivo_ruta ON gen_archivo USING btree (ruta) WHERE (estado = 1);

ALTER TABLE gen_archivo
    ADD CONSTRAINT gen_archivo_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE gen_archivo
    ADD CONSTRAINT gen_archivo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_archivo
    ADD CONSTRAINT gen_archivo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
