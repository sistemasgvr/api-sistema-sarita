-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_vehiculo
-- Generated: 2026-09-02T21:48:53.376Z

CREATE TABLE gen_vehiculo (
    id integer NOT NULL,
    id_cliente integer,
    id_tipo_vehiculo integer,
    placa character varying(20) NOT NULL,
    placa2 character varying(20),
    marca character varying(100),
    marca2 character varying(100),
    modelo character varying(100),
    anio integer,
    color character varying(50),
    certificado_inscripcion character varying(50),
    certificado2 character varying(50),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_vehiculo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_vehiculo_id_seq OWNED BY public.gen_vehiculo.id;

ALTER TABLE gen_vehiculo ALTER COLUMN id SET DEFAULT nextval('public.gen_vehiculo_id_seq'::regclass);

ALTER TABLE gen_vehiculo
    ADD CONSTRAINT gen_vehiculo_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_vehiculo_cliente ON gen_vehiculo USING btree (id_cliente);

CREATE INDEX idx_gen_vehiculo_placa ON gen_vehiculo USING btree (placa);

CREATE UNIQUE INDEX idx_gen_vehiculo_placa_cliente ON gen_vehiculo USING btree (id_cliente, placa) WHERE (id_cliente IS NOT NULL);

CREATE UNIQUE INDEX idx_gen_vehiculo_placa_empresa ON gen_vehiculo USING btree (placa) WHERE (id_cliente IS NULL);

ALTER TABLE gen_vehiculo
    ADD CONSTRAINT gen_vehiculo_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE gen_vehiculo
    ADD CONSTRAINT gen_vehiculo_id_tipo_vehiculo_fkey FOREIGN KEY (id_tipo_vehiculo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_vehiculo
    ADD CONSTRAINT gen_vehiculo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_vehiculo
    ADD CONSTRAINT gen_vehiculo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
