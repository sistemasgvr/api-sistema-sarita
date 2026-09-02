-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: cli_clientes
-- Generated: 2026-09-02T21:44:33.089Z

CREATE TABLE cli_clientes (
    id integer NOT NULL,
    codigo_interno character varying(20),
    razon_social character varying(300),
    id_tipo_cliente integer,
    id_tipo_persona integer,
    nombres character varying(200),
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    id_tipo_documento integer,
    numero_documento character varying(20),
    direccion character varying(255),
    referencia character varying(255),
    telefono character varying(30),
    email character varying(150),
    es_agente_percepcion boolean DEFAULT false,
    es_buen_contribuyente boolean DEFAULT false,
    es_agente_retenedor boolean DEFAULT false,
    afecto_rus boolean DEFAULT false,
    situacion_sunat character varying(50),
    estado_contribuyente_sunat character varying(50),
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE cli_clientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE cli_clientes_id_seq OWNED BY public.cli_clientes.id;

ALTER TABLE cli_clientes ALTER COLUMN id SET DEFAULT nextval('public.cli_clientes_id_seq'::regclass);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_codigo_interno_key UNIQUE (codigo_interno);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_numero_documento_key UNIQUE (numero_documento);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_pkey PRIMARY KEY (id);

CREATE INDEX idx_cli_clientes_codigo ON cli_clientes USING btree (codigo_interno);

CREATE INDEX idx_cli_clientes_numdoc ON cli_clientes USING btree (numero_documento);

CREATE INDEX idx_cli_clientes_razon ON cli_clientes USING btree (razon_social);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_id_tipo_cliente_fkey FOREIGN KEY (id_tipo_cliente) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_id_tipo_documento_fkey FOREIGN KEY (id_tipo_documento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_id_tipo_persona_fkey FOREIGN KEY (id_tipo_persona) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_clientes
    ADD CONSTRAINT cli_clientes_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
