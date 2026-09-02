-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: cli_direcciones
-- Generated: 2026-09-02T21:44:49.960Z

CREATE TABLE cli_direcciones (
    id integer NOT NULL,
    id_cliente integer NOT NULL,
    descripcion character varying(150),
    direccion character varying(255) NOT NULL,
    id_departamento integer,
    id_provincia integer,
    id_distrito integer,
    referencia character varying(255),
    es_principal boolean DEFAULT false,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_pais integer,
    latitud numeric(10,8),
    longitud numeric(11,8)
);

CREATE SEQUENCE cli_direcciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE cli_direcciones_id_seq OWNED BY public.cli_direcciones.id;

ALTER TABLE cli_direcciones ALTER COLUMN id SET DEFAULT nextval('public.cli_direcciones_id_seq'::regclass);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_pkey PRIMARY KEY (id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.gen_departamento(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_distrito_fkey FOREIGN KEY (id_distrito) REFERENCES public.gen_distrito(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES public.gen_provincia(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT cli_direcciones_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_direcciones
    ADD CONSTRAINT fk_cli_direcciones_gen_pais FOREIGN KEY (id_pais) REFERENCES public.gen_pais(id);
