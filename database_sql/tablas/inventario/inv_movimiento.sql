-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: inv_movimiento
-- Generated: 2026-09-02T21:49:35.472Z

CREATE TABLE inv_movimiento (
    id integer NOT NULL,
    fecha timestamp without time zone DEFAULT now() NOT NULL,
    id_tipo_movimiento integer NOT NULL,
    naturaleza character varying(10) NOT NULL,
    id_producto integer,
    id_balon integer,
    cantidad numeric(12,4) DEFAULT 0 NOT NULL,
    id_unidad_medida integer,
    id_almacen_origen integer,
    id_almacen_destino integer,
    id_cliente integer,
    id_documento_origen integer,
    id_tipo_documento_origen integer,
    id_documento_detalle integer,
    id_movimiento_padre integer,
    stock_anterior numeric(12,4),
    stock_nuevo numeric(12,4),
    id_estado_balon_snapshot integer,
    id_estado_balon_anterior integer,
    id_cliente_ubicacion_anterior integer,
    id_almacen_anterior integer,
    glosa character varying(300),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    id_usuario_modificacion integer,
    fecha_modificacion timestamp without time zone,
    CONSTRAINT chk_inv_movimiento_naturaleza CHECK (((((naturaleza)::text = 'PRODUCTO'::text) AND (id_producto IS NOT NULL) AND (id_balon IS NULL)) OR (((naturaleza)::text = 'BALON'::text) AND (id_balon IS NOT NULL)))),
    CONSTRAINT inv_movimiento_naturaleza_check CHECK (((naturaleza)::text = ANY ((ARRAY['PRODUCTO'::character varying, 'BALON'::character varying])::text[])))
);

CREATE SEQUENCE inv_movimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE inv_movimiento_id_seq OWNED BY public.inv_movimiento.id;

ALTER TABLE inv_movimiento ALTER COLUMN id SET DEFAULT nextval('public.inv_movimiento_id_seq'::regclass);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_pkey PRIMARY KEY (id);

CREATE INDEX idx_inv_movimiento_balon ON inv_movimiento USING btree (id_balon, fecha);

CREATE INDEX idx_inv_movimiento_doc ON inv_movimiento USING btree (id_tipo_documento_origen, id_documento_origen);

CREATE INDEX idx_inv_movimiento_doc_detalle ON inv_movimiento USING btree (id_tipo_documento_origen, id_documento_origen, id_documento_detalle);

CREATE INDEX idx_inv_movimiento_padre ON inv_movimiento USING btree (id_movimiento_padre);

CREATE INDEX idx_inv_movimiento_producto ON inv_movimiento USING btree (id_producto, id_almacen_origen, fecha);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_almacen_destino_fkey FOREIGN KEY (id_almacen_destino) REFERENCES public.gen_almacen(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_almacen_origen_fkey FOREIGN KEY (id_almacen_origen) REFERENCES public.gen_almacen(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_estado_balon_snapshot_fkey FOREIGN KEY (id_estado_balon_snapshot) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_estado_balon_anterior_fkey FOREIGN KEY (id_estado_balon_anterior) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_almacen_anterior_fkey FOREIGN KEY (id_almacen_anterior) REFERENCES public.gen_almacen(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_movimiento_padre_fkey FOREIGN KEY (id_movimiento_padre) REFERENCES public.inv_movimiento(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_tipo_documento_origen_fkey FOREIGN KEY (id_tipo_documento_origen) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_tipo_movimiento_fkey FOREIGN KEY (id_tipo_movimiento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE inv_movimiento
    ADD CONSTRAINT inv_movimiento_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
