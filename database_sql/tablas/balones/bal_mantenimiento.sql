-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_mantenimiento
-- Generated: 2026-09-02T21:42:44.054Z

CREATE TABLE bal_mantenimiento (
    id integer NOT NULL,
    id_balon integer,
    id_tipo_mantenimiento integer,
    fecha_ingreso date NOT NULL,
    fecha_salida date,
    descripcion character varying(500),
    costo numeric(10,4) DEFAULT 0,
    es_externo boolean DEFAULT false,
    id_proveedor integer,
    id_estado integer,
    id_comprobante_venta integer,
    id_comprobante_compra integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_producto integer,
    id_almacen integer,
    id_alquiler integer,
    id_recojo integer,
    CONSTRAINT chk_bal_mantenimiento_origen CHECK (((((id_balon IS NOT NULL))::integer + ((id_producto IS NOT NULL))::integer) = 1))
);

CREATE SEQUENCE bal_mantenimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_mantenimiento_id_seq OWNED BY public.bal_mantenimiento.id;

ALTER TABLE bal_mantenimiento ALTER COLUMN id SET DEFAULT nextval('public.bal_mantenimiento_id_seq'::regclass);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_pkey PRIMARY KEY (id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_comprobante_venta_fkey FOREIGN KEY (id_comprobante_venta) REFERENCES public.ven_comprobante(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_recojo_fkey FOREIGN KEY (id_recojo) REFERENCES public.bal_recojo(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_tipo_mantenimiento_fkey FOREIGN KEY (id_tipo_mantenimiento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_mantenimiento
    ADD CONSTRAINT bal_mantenimiento_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
