-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: auth_permisos
-- Generated: 2026-09-02T21:40:54.728Z

CREATE TABLE auth_permisos (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    estado boolean DEFAULT true NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE auth_permisos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE auth_permisos_id_seq OWNED BY public.auth_permisos.id;

ALTER TABLE auth_permisos ALTER COLUMN id SET DEFAULT nextval('public.auth_permisos_id_seq'::regclass);

ALTER TABLE auth_permisos
    ADD CONSTRAINT auth_permisos_pkey PRIMARY KEY (id);

ALTER TABLE auth_permisos
    ADD CONSTRAINT auth_permisos_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE auth_permisos
    ADD CONSTRAINT auth_permisos_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
