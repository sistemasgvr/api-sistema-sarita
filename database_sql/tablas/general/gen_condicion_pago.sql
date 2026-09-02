-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_condicion_pago
-- Generated: 2026-09-02T21:46:47.791Z

CREATE TABLE gen_condicion_pago (
    id integer NOT NULL,
    codigo character varying(10) NOT NULL,
    nombre character varying(100) NOT NULL,
    dias_credito integer DEFAULT 0 NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    numero_cuotas integer,
    dia_mes_pago integer,
    CONSTRAINT chk_gen_condicion_pago_cuotas CHECK (((numero_cuotas IS NULL) OR ((numero_cuotas >= 1) AND ((numero_cuotas = 1) OR ((dia_mes_pago IS NOT NULL) AND ((dia_mes_pago >= 1) AND (dia_mes_pago <= 31)))))))
);

CREATE SEQUENCE gen_condicion_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_condicion_pago_id_seq OWNED BY public.gen_condicion_pago.id;

ALTER TABLE gen_condicion_pago ALTER COLUMN id SET DEFAULT nextval('public.gen_condicion_pago_id_seq'::regclass);

ALTER TABLE gen_condicion_pago
    ADD CONSTRAINT gen_condicion_pago_codigo_key UNIQUE (codigo);

ALTER TABLE gen_condicion_pago
    ADD CONSTRAINT gen_condicion_pago_pkey PRIMARY KEY (id);

ALTER TABLE gen_condicion_pago
    ADD CONSTRAINT gen_condicion_pago_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_condicion_pago
    ADD CONSTRAINT gen_condicion_pago_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
