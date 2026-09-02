-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_clasificacion_gasto
-- Generated: 2026-09-02T21:46:39.356Z

CREATE TABLE gen_clasificacion_gasto (
    id integer NOT NULL,
    grupo character varying(100) NOT NULL,
    subgrupo character varying(100) NOT NULL,
    sub_subgrupo character varying(100) NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_clasificacion_gasto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_clasificacion_gasto_id_seq OWNED BY public.gen_clasificacion_gasto.id;

ALTER TABLE gen_clasificacion_gasto ALTER COLUMN id SET DEFAULT nextval('public.gen_clasificacion_gasto_id_seq'::regclass);

ALTER TABLE gen_clasificacion_gasto
    ADD CONSTRAINT gen_clasificacion_gasto_grupo_subgrupo_sub_subgrupo_key UNIQUE (grupo, subgrupo, sub_subgrupo);

ALTER TABLE gen_clasificacion_gasto
    ADD CONSTRAINT gen_clasificacion_gasto_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_clasificacion_gasto ON gen_clasificacion_gasto USING btree (grupo, subgrupo);

ALTER TABLE gen_clasificacion_gasto
    ADD CONSTRAINT gen_clasificacion_gasto_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_clasificacion_gasto
    ADD CONSTRAINT gen_clasificacion_gasto_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
