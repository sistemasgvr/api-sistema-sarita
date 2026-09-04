-- Table: gen_cuenta_medio_pago
-- Escrita a mano en Fase 3 (pg_dump no disponible en el equipo, así que
-- sync-tables-from-dev.js no pudo generarla). DDL espejo de
-- migraciones/20260904_f3_caja_medios_pago_cuentas.sql.
--
-- Puente N:M entre una cuenta bancaria de la EMPRESA y los medios de pago que
-- recibe. Una cuenta BCP puede aceptar transferencia y además tener Yape.

CREATE TABLE gen_cuenta_medio_pago (
    id integer NOT NULL,
    id_cuenta_bancaria integer NOT NULL,
    id_medio_pago integer NOT NULL,
    es_predeterminada boolean DEFAULT false NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_cuenta_medio_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_cuenta_medio_pago_id_seq OWNED BY public.gen_cuenta_medio_pago.id;

ALTER TABLE gen_cuenta_medio_pago ALTER COLUMN id SET DEFAULT nextval('public.gen_cuenta_medio_pago_id_seq'::regclass);

ALTER TABLE gen_cuenta_medio_pago
    ADD CONSTRAINT gen_cuenta_medio_pago_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX uq_gen_cuenta_medio_pago ON gen_cuenta_medio_pago USING btree (id_cuenta_bancaria, id_medio_pago) WHERE (estado = 1);

CREATE INDEX idx_gen_cuenta_medio_pago_medio ON gen_cuenta_medio_pago USING btree (id_medio_pago) WHERE (estado = 1);

ALTER TABLE gen_cuenta_medio_pago
    ADD CONSTRAINT gen_cuenta_medio_pago_id_cuenta_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria(id) ON DELETE CASCADE;

ALTER TABLE gen_cuenta_medio_pago
    ADD CONSTRAINT gen_cuenta_medio_pago_id_medio_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_cuenta_medio_pago
    ADD CONSTRAINT gen_cuenta_medio_pago_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_cuenta_medio_pago
    ADD CONSTRAINT gen_cuenta_medio_pago_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
