-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: pro_stock
-- Generated: 2026-09-02T21:50:17.676Z

CREATE TABLE pro_stock (
    id integer NOT NULL,
    id_almacen integer NOT NULL,
    id_producto integer NOT NULL,
    stock numeric(12,4) DEFAULT 0 NOT NULL,
    stock_minimo numeric(12,4) DEFAULT 0,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE pro_stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pro_stock_id_seq OWNED BY public.pro_stock.id;

ALTER TABLE pro_stock ALTER COLUMN id SET DEFAULT nextval('public.pro_stock_id_seq'::regclass);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_id_almacen_id_producto_key UNIQUE (id_almacen, id_producto);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_pkey PRIMARY KEY (id);

CREATE INDEX idx_pro_stock_almacen ON pro_stock USING btree (id_almacen, id_producto);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE pro_stock
    ADD CONSTRAINT pro_stock_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
