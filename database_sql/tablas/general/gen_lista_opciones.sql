-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_lista_opciones
-- Generated: 2026-09-02T21:48:11.553Z

CREATE TABLE gen_lista_opciones (
    id integer NOT NULL,
    id_lista integer NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_lista_opciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_lista_opciones_id_seq OWNED BY public.gen_lista_opciones.id;

ALTER TABLE gen_lista_opciones ALTER COLUMN id SET DEFAULT nextval('public.gen_lista_opciones_id_seq'::regclass);

ALTER TABLE gen_lista_opciones
    ADD CONSTRAINT gen_lista_opciones_pkey PRIMARY KEY (id);

ALTER TABLE gen_lista_opciones
    ADD CONSTRAINT gen_lista_opciones_id_lista_fkey FOREIGN KEY (id_lista) REFERENCES public.gen_lista(id);

ALTER TABLE gen_lista_opciones
    ADD CONSTRAINT gen_lista_opciones_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_lista_opciones
    ADD CONSTRAINT gen_lista_opciones_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
