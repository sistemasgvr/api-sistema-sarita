-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_alquiler
-- Generated: 2026-09-02T21:41:45.049Z

CREATE TABLE bal_alquiler (
    id integer NOT NULL,
    numero_alquiler character varying(30) NOT NULL,
    id_cliente integer NOT NULL,
    id_almacen integer NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin_pactada date,
    fecha_fin_real date,
    tarifa_diaria numeric(10,4) DEFAULT 0,
    total_cobrado numeric(12,4) DEFAULT 0,
    id_estado integer,
    observacion character varying(500),
    id_comprobante_venta integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_producto_regulador integer,
    dias_periodo integer DEFAULT 14 NOT NULL,
    id_producto_stock integer,
    fecha_devolucion_regulador date,
    id_condicion_regulador integer,
    stock_regulador_reingresado boolean DEFAULT false NOT NULL,
    id_mantenimiento_regulador integer
);

CREATE SEQUENCE bal_alquiler_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_alquiler_id_seq OWNED BY public.bal_alquiler.id;

ALTER TABLE bal_alquiler ALTER COLUMN id SET DEFAULT nextval('public.bal_alquiler_id_seq'::regclass);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_numero_alquiler_key UNIQUE (numero_alquiler);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_alquiler_cliente ON bal_alquiler USING btree (id_cliente);

CREATE INDEX idx_bal_alquiler_producto_regulador ON bal_alquiler USING btree (id_producto_regulador) WHERE (id_producto_regulador IS NOT NULL);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_comprobante_venta_fkey FOREIGN KEY (id_comprobante_venta) REFERENCES public.ven_comprobante(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_condicion_regulador_fkey FOREIGN KEY (id_condicion_regulador) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_mantenimiento_regulador_fkey FOREIGN KEY (id_mantenimiento_regulador) REFERENCES public.bal_mantenimiento(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_producto_regulador_fkey FOREIGN KEY (id_producto_regulador) REFERENCES public.pro_producto(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_producto_stock_fkey FOREIGN KEY (id_producto_stock) REFERENCES public.pro_producto(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_alquiler
    ADD CONSTRAINT bal_alquiler_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
