-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_comprobante_detalle
-- Generated: 2026-09-02T21:50:51.195Z

CREATE TABLE ven_comprobante_detalle (
    id integer NOT NULL,
    id_comprobante integer NOT NULL,
    item integer NOT NULL,
    id_producto integer NOT NULL,
    descripcion character varying(300),
    id_unidad_medida integer,
    cantidad numeric(12,4) NOT NULL,
    precio_unitario numeric(12,6) NOT NULL,
    descuento numeric(12,4) DEFAULT 0,
    valor_venta numeric(12,4),
    porcentaje_igv numeric(6,4) DEFAULT 18,
    id_afectacion_igv integer,
    impuesto numeric(12,4),
    importe numeric(12,4),
    id_balon integer,
    capacidad_cilindro numeric(10,4),
    id_estado_cilindro integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_comprobante_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_comprobante_detalle_id_seq OWNED BY public.ven_comprobante_detalle.id;

ALTER TABLE ven_comprobante_detalle ALTER COLUMN id SET DEFAULT nextval('public.ven_comprobante_detalle_id_seq'::regclass);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_detalle_comprobante ON ven_comprobante_detalle USING btree (id_comprobante);

CREATE INDEX idx_ven_detalle_estado_cil ON ven_comprobante_detalle USING btree (id_estado_cilindro);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_afectacion_igv_fkey FOREIGN KEY (id_afectacion_igv) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_estado_cilindro_fkey FOREIGN KEY (id_estado_cilindro) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_comprobante_detalle
    ADD CONSTRAINT ven_comprobante_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
