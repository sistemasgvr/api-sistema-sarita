-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: doc_salida_detalle
-- Generated: 2026-09-03T16:49:04.835Z

CREATE TABLE doc_salida_detalle (
    id integer NOT NULL,
    id_doc_salida integer NOT NULL,
    item integer NOT NULL,
    id_producto integer,
    id_balon integer,
    descripcion character varying(300),
    id_unidad_medida integer,
    cantidad numeric(12,4) DEFAULT 0 NOT NULL,
    glosa character varying(300),
    id_movimiento integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp without time zone
);

CREATE SEQUENCE doc_salida_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE doc_salida_detalle_id_seq OWNED BY public.doc_salida_detalle.id;

ALTER TABLE doc_salida_detalle ALTER COLUMN id SET DEFAULT nextval('public.doc_salida_detalle_id_seq'::regclass);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT chk_doc_salida_detalle_item CHECK (((id_producto IS NOT NULL) OR (id_balon IS NOT NULL)));

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_doc_salida_detalle_balon ON public.doc_salida_detalle USING btree (id_balon);

CREATE INDEX idx_doc_salida_detalle_doc ON public.doc_salida_detalle USING btree (id_doc_salida);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_movimiento_fkey FOREIGN KEY (id_movimiento) REFERENCES public.inv_movimiento(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_salida_detalle
    ADD CONSTRAINT doc_salida_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
