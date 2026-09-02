-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: pro_categoria
-- Generated: 2026-09-02T21:49:52.450Z

CREATE TABLE pro_categoria (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE pro_categoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pro_categoria_id_seq OWNED BY public.pro_categoria.id;

ALTER TABLE pro_categoria ALTER COLUMN id SET DEFAULT nextval('public.pro_categoria_id_seq'::regclass);

ALTER TABLE pro_categoria
    ADD CONSTRAINT pro_categoria_pkey PRIMARY KEY (id);

ALTER TABLE pro_categoria
    ADD CONSTRAINT pro_categoria_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE pro_categoria
    ADD CONSTRAINT pro_categoria_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
