-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: age_actividad_item
-- Generated: 2026-09-09T16:16:56.925Z
CREATE TABLE age_actividad_item (
    id integer NOT NULL,
    id_actividad integer NOT NULL,
    item integer NOT NULL,
    id_producto integer,
    descripcion character varying(300),
    cantidad numeric(12,4) DEFAULT 1 NOT NULL,
    id_balon integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_venta_detalle integer,
    id_doc_salida_detalle integer,
    id_prestamo_detalle integer,
    id_estado_verificacion_salida integer,
    id_estado_verificacion_llegada integer,
    observacion_salida character varying(500),
    observacion_llegada character varying(500),
    id_estado_producto_recogido integer
);

CREATE SEQUENCE age_actividad_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE age_actividad_item_id_seq OWNED BY public.age_actividad_item.id;

ALTER TABLE age_actividad_item ALTER COLUMN id SET DEFAULT nextval('public.age_actividad_item_id_seq'::regclass);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_pkey PRIMARY KEY (id);

CREATE INDEX idx_age_actividad_item_act ON age_actividad_item USING btree (id_actividad) WHERE (estado = 1);

CREATE INDEX idx_age_item_doc_det ON age_actividad_item USING btree (id_doc_salida_detalle);

CREATE INDEX idx_age_item_prestamo_det ON age_actividad_item USING btree (id_prestamo_detalle);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_actividad_fkey FOREIGN KEY (id_actividad) REFERENCES public.age_actividad(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_doc_salida_detalle_fkey FOREIGN KEY (id_doc_salida_detalle) REFERENCES public.doc_salida_detalle(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_estado_producto_recogido_fkey FOREIGN KEY (id_estado_producto_recogido) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_estado_verificacion_llegada_fkey FOREIGN KEY (id_estado_verificacion_llegada) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_estado_verificacion_salida_fkey FOREIGN KEY (id_estado_verificacion_salida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_prestamo_detalle_fkey FOREIGN KEY (id_prestamo_detalle) REFERENCES public.bal_prestamo_detalle(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE age_actividad_item
    ADD CONSTRAINT age_actividad_item_id_venta_detalle_fkey FOREIGN KEY (id_venta_detalle) REFERENCES public.ven_comprobante_detalle(id);
