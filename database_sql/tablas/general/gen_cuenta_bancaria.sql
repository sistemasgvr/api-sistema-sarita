-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_cuenta_bancaria
-- Generated: 2026-09-02T21:47:12.963Z

CREATE TABLE gen_cuenta_bancaria (
    id integer NOT NULL,
    id_cliente integer,
    id_banco integer,
    id_tipo_cuenta integer,
    titular character varying(200),
    numero_cuenta character varying(30),
    numero_cuenta_interbancaria character varying(30),
    telefono_billetera character varying(20),
    es_principal boolean DEFAULT false,
    -- Fase 3: CLIENTE = cuenta del cliente (devoluciones);
    -- EMPRESA = cuenta propia que recibe los cobros. Las de EMPRESA se comparten
    -- entre sucursales: la sucursal ya queda en el movimiento que usa la cuenta.
    ambito character varying(10) DEFAULT 'CLIENTE'::character varying NOT NULL,
    alias character varying(100),
    id_empresa integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_cuenta_bancaria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_cuenta_bancaria_id_seq OWNED BY public.gen_cuenta_bancaria.id;

ALTER TABLE gen_cuenta_bancaria ALTER COLUMN id SET DEFAULT nextval('public.gen_cuenta_bancaria_id_seq'::regclass);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_cuenta_cliente ON gen_cuenta_bancaria USING btree (id_cliente);

CREATE INDEX idx_gen_cuenta_ambito ON gen_cuenta_bancaria USING btree (ambito) WHERE (estado = 1);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_ambito_check CHECK (((ambito)::text = ANY ((ARRAY['CLIENTE'::character varying, 'EMPRESA'::character varying])::text[])));

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_ambito_coherente CHECK (((((ambito)::text = 'CLIENTE'::text) AND (id_cliente IS NOT NULL)) OR (((ambito)::text = 'EMPRESA'::text) AND (id_cliente IS NULL))));

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_tipo_cuenta_fkey FOREIGN KEY (id_tipo_cuenta) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_cuenta_bancaria
    ADD CONSTRAINT gen_cuenta_bancaria_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
