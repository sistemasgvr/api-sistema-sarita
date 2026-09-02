-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: fin_cuenta
-- Generated: 2026-09-02T21:45:49.141Z

CREATE TABLE fin_cuenta (
    id integer NOT NULL,
    id_tipo_cuenta integer NOT NULL,
    id_tercero integer,
    id_comprobante_venta integer,
    id_comprobante_compra integer,
    id_cuota integer,
    fecha_emision date NOT NULL,
    fecha_vencimiento date,
    monto_pendiente numeric(12,4) NOT NULL,
    monto_abonado numeric(12,4) DEFAULT 0,
    monto_saldo numeric(12,4),
    id_estado integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    tercero_nombre character varying(255),
    id_cuenta_padre integer,
    numero_cuota integer,
    numero_cuotas_total integer,
    descripcion character varying(255),
    id_banco integer,
    tasa_interes numeric(8,4),
    numero_comprobante character varying(50),
    CONSTRAINT fin_cuenta_tercero_check CHECK (((id_tercero IS NOT NULL) OR (tercero_nombre IS NOT NULL)))
);

CREATE SEQUENCE fin_cuenta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fin_cuenta_id_seq OWNED BY public.fin_cuenta.id;

ALTER TABLE fin_cuenta ALTER COLUMN id SET DEFAULT nextval('public.fin_cuenta_id_seq'::regclass);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_cuenta_padre ON fin_cuenta USING btree (id_cuenta_padre);

CREATE INDEX idx_fin_cuenta_tipo_estado ON fin_cuenta USING btree (id_tipo_cuenta, estado);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_banco_fkey FOREIGN KEY (id_banco) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_comprobante_venta_fkey FOREIGN KEY (id_comprobante_venta) REFERENCES public.ven_comprobante(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_cuenta_padre_fkey FOREIGN KEY (id_cuenta_padre) REFERENCES public.fin_cuenta(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_cuota_fkey FOREIGN KEY (id_cuota) REFERENCES public.ven_cuotas(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_tercero_fkey FOREIGN KEY (id_tercero) REFERENCES public.cli_clientes(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_tipo_cuenta_fkey FOREIGN KEY (id_tipo_cuenta) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_cuenta
    ADD CONSTRAINT fin_cuenta_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
