-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_distrito
-- Generated: 2026-09-02T21:47:29.816Z

CREATE TABLE gen_distrito (
    id integer NOT NULL,
    id_provincia integer NOT NULL,
    nombre character varying(100) NOT NULL,
    codigo_ubigeo character varying(6),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_distrito_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_distrito_id_seq OWNED BY public.gen_distrito.id;

ALTER TABLE gen_distrito ALTER COLUMN id SET DEFAULT nextval('public.gen_distrito_id_seq'::regclass);

ALTER TABLE gen_distrito
    ADD CONSTRAINT gen_distrito_pkey PRIMARY KEY (id);

ALTER TABLE gen_distrito
    ADD CONSTRAINT gen_distrito_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES public.gen_provincia(id);

ALTER TABLE gen_distrito
    ADD CONSTRAINT gen_distrito_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_distrito
    ADD CONSTRAINT gen_distrito_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
