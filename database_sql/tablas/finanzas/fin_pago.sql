-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: fin_pago
-- Generated: 2026-09-02T21:46:05.946Z

CREATE TABLE fin_pago (
    id integer NOT NULL,
    id_cuenta integer NOT NULL,
    fecha_pago date NOT NULL,
    monto numeric(12,4) NOT NULL,
    id_medio_pago integer,
    referencia character varying(100),
    observacion character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_cuenta_bancaria integer,
    numero_operacion character varying(50),
    id_sucursal integer
);

CREATE SEQUENCE fin_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fin_pago_id_seq OWNED BY public.fin_pago.id;

ALTER TABLE fin_pago ALTER COLUMN id SET DEFAULT nextval('public.fin_pago_id_seq'::regclass);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_pkey PRIMARY KEY (id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria(id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_cuenta_fkey FOREIGN KEY (id_cuenta) REFERENCES public.fin_cuenta(id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_pago
    ADD CONSTRAINT fin_pago_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
