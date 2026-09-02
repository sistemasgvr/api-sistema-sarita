-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_almacen
-- Generated: 2026-09-02T21:46:14.313Z

CREATE TABLE gen_almacen (
    id integer NOT NULL,
    id_sucursal integer NOT NULL,
    nombre character varying(150) NOT NULL,
    ubicacion character varying(255),
    descripcion character varying(255),
    id_departamento integer,
    id_provincia integer,
    id_distrito integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_almacen_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_almacen_id_seq OWNED BY public.gen_almacen.id;

ALTER TABLE gen_almacen ALTER COLUMN id SET DEFAULT nextval('public.gen_almacen_id_seq'::regclass);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_pkey PRIMARY KEY (id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.gen_departamento(id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_distrito_fkey FOREIGN KEY (id_distrito) REFERENCES public.gen_distrito(id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES public.gen_provincia(id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_almacen
    ADD CONSTRAINT gen_almacen_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
