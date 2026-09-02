-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_departamento
-- Generated: 2026-09-02T21:47:21.415Z

CREATE TABLE gen_departamento (
    id integer NOT NULL,
    id_pais integer NOT NULL,
    nombre character varying(100) NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_departamento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_departamento_id_seq OWNED BY public.gen_departamento.id;

ALTER TABLE gen_departamento ALTER COLUMN id SET DEFAULT nextval('public.gen_departamento_id_seq'::regclass);

ALTER TABLE gen_departamento
    ADD CONSTRAINT gen_departamento_pkey PRIMARY KEY (id);

ALTER TABLE gen_departamento
    ADD CONSTRAINT gen_departamento_id_pais_fkey FOREIGN KEY (id_pais) REFERENCES public.gen_pais(id);

ALTER TABLE gen_departamento
    ADD CONSTRAINT gen_departamento_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_departamento
    ADD CONSTRAINT gen_departamento_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
