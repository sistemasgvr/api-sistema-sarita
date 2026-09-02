-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_chofer
-- Generated: 2026-09-02T21:46:30.921Z

CREATE TABLE gen_chofer (
    id integer NOT NULL,
    id_cliente integer,
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    nombres character varying(150),
    id_tipo_documento integer,
    numero_documento character varying(20),
    telefono character varying(20),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_trabajador integer
);

CREATE SEQUENCE gen_chofer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_chofer_id_seq OWNED BY public.gen_chofer.id;

ALTER TABLE gen_chofer ALTER COLUMN id SET DEFAULT nextval('public.gen_chofer_id_seq'::regclass);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_chofer_cliente ON gen_chofer USING btree (id_cliente);

CREATE INDEX idx_gen_chofer_documento ON gen_chofer USING btree (numero_documento);

CREATE INDEX idx_gen_chofer_trabajador ON gen_chofer USING btree (id_trabajador) WHERE (id_trabajador IS NOT NULL);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_id_tipo_documento_fkey FOREIGN KEY (id_tipo_documento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_id_trabajador_fkey FOREIGN KEY (id_trabajador) REFERENCES public.tra_trabajadores(id);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_chofer
    ADD CONSTRAINT gen_chofer_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
