-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: cli_contacto
-- Generated: 2026-09-02T21:44:41.501Z

CREATE TABLE cli_contacto (
    id integer NOT NULL,
    id_cliente integer NOT NULL,
    nombre character varying(150),
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    direccion character varying(255),
    email character varying(150),
    telefono1 character varying(20),
    telefono2 character varying(20),
    telefono3 character varying(20),
    es_principal boolean DEFAULT false,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE cli_contacto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE cli_contacto_id_seq OWNED BY public.cli_contacto.id;

ALTER TABLE cli_contacto ALTER COLUMN id SET DEFAULT nextval('public.cli_contacto_id_seq'::regclass);

ALTER TABLE cli_contacto
    ADD CONSTRAINT cli_contacto_pkey PRIMARY KEY (id);

CREATE INDEX idx_cli_contacto_cliente ON cli_contacto USING btree (id_cliente);

ALTER TABLE cli_contacto
    ADD CONSTRAINT cli_contacto_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE cli_contacto
    ADD CONSTRAINT cli_contacto_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_contacto
    ADD CONSTRAINT cli_contacto_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
