-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_configuracion_servicio
-- Generated: 2026-09-02T21:46:56.125Z

CREATE TABLE gen_configuracion_servicio (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(100) NOT NULL,
    usuario character varying(150),
    contrasena character varying(255),
    email character varying(150),
    url character varying(255),
    observacion character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    token text,
    timeout_ms integer DEFAULT 60000,
    habilitado boolean DEFAULT true,
    client_id character varying(255),
    client_secret character varying(255),
    ruc_emisor character varying(11)
);

CREATE SEQUENCE gen_configuracion_servicio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_configuracion_servicio_id_seq OWNED BY public.gen_configuracion_servicio.id;

ALTER TABLE gen_configuracion_servicio ALTER COLUMN id SET DEFAULT nextval('public.gen_configuracion_servicio_id_seq'::regclass);

ALTER TABLE gen_configuracion_servicio
    ADD CONSTRAINT gen_configuracion_servicio_codigo_key UNIQUE (codigo);

ALTER TABLE gen_configuracion_servicio
    ADD CONSTRAINT gen_configuracion_servicio_pkey PRIMARY KEY (id);

ALTER TABLE gen_configuracion_servicio
    ADD CONSTRAINT gen_configuracion_servicio_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_configuracion_servicio
    ADD CONSTRAINT gen_configuracion_servicio_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
