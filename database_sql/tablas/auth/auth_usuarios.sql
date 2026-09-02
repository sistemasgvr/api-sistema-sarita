-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: auth_usuarios
-- Generated: 2026-09-02T21:41:28.266Z

CREATE TABLE auth_usuarios (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    correo character varying(150) NOT NULL,
    contrasena character varying(255) NOT NULL,
    estado boolean DEFAULT true NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_trabajador integer
);

CREATE SEQUENCE auth_usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE auth_usuarios_id_seq OWNED BY public.auth_usuarios.id;

ALTER TABLE auth_usuarios ALTER COLUMN id SET DEFAULT nextval('public.auth_usuarios_id_seq'::regclass);

ALTER TABLE auth_usuarios
    ADD CONSTRAINT auth_usuarios_correo_key UNIQUE (correo);

ALTER TABLE auth_usuarios
    ADD CONSTRAINT auth_usuarios_pkey PRIMARY KEY (id);

CREATE INDEX idx_auth_usuarios_trabajador ON auth_usuarios USING btree (id_trabajador) WHERE (id_trabajador IS NOT NULL);

ALTER TABLE auth_usuarios
    ADD CONSTRAINT auth_usuarios_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.tra_trabajadores(id);
