-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_prestamo
-- Generated: 2026-09-02T21:43:09.185Z

CREATE TABLE bal_prestamo (
    id integer NOT NULL,
    numero_prestamo character varying(30),
    id_tipo_prestamo integer NOT NULL,
    id_cliente integer,
    id_proveedor integer,
    id_almacen integer,
    fecha_salida date,
    fecha_retorno_pactada date,
    fecha_retorno_real date,
    titulo character varying(200),
    observacion character varying(500),
    id_estado integer,
    id_comprobante_venta integer,
    id_comprobante_compra integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_prestamo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_prestamo_id_seq OWNED BY public.bal_prestamo.id;

ALTER TABLE bal_prestamo ALTER COLUMN id SET DEFAULT nextval('public.bal_prestamo_id_seq'::regclass);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_numero_prestamo_key UNIQUE (numero_prestamo);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_prestamo_cliente ON bal_prestamo USING btree (id_cliente);

CREATE INDEX idx_bal_prestamo_proveedor ON bal_prestamo USING btree (id_proveedor);

CREATE INDEX idx_bal_prestamo_tipo ON bal_prestamo USING btree (id_tipo_prestamo);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_comprobante_venta_fkey FOREIGN KEY (id_comprobante_venta) REFERENCES public.ven_comprobante(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_tipo_prestamo_fkey FOREIGN KEY (id_tipo_prestamo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
