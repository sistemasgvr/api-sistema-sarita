-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: fin_caja_deposito
-- Generated: 2026-09-02T21:45:15.203Z

CREATE TABLE fin_caja_deposito (
    id integer NOT NULL,
    id_sesion integer,
    fecha date NOT NULL,
    monto numeric(12,4) NOT NULL,
    id_cuenta_bancaria integer,
    id_medio_pago integer,
    numero_operacion character varying(80),
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    CONSTRAINT fin_caja_deposito_monto_check CHECK ((monto > (0)::numeric))
);

CREATE SEQUENCE fin_caja_deposito_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fin_caja_deposito_id_seq OWNED BY public.fin_caja_deposito.id;

ALTER TABLE fin_caja_deposito ALTER COLUMN id SET DEFAULT nextval('public.fin_caja_deposito_id_seq'::regclass);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_caja_deposito_fecha ON fin_caja_deposito USING btree (fecha) WHERE (estado = 1);

CREATE INDEX idx_fin_caja_deposito_sesion ON fin_caja_deposito USING btree (id_sesion) WHERE (estado = 1);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria(id);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_id_sesion_fkey FOREIGN KEY (id_sesion) REFERENCES public.fin_caja_sesion(id);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_caja_deposito
    ADD CONSTRAINT fin_caja_deposito_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
