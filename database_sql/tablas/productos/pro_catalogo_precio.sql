-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: pro_catalogo_precio
-- Generated: 2026-09-02T21:49:44.025Z

CREATE TABLE pro_catalogo_precio (
    id integer NOT NULL,
    id_tipo_catalogo integer NOT NULL,
    periodo character varying(20),
    nombre_item character varying(200) NOT NULL,
    id_producto integer,
    id_tipo_balon integer,
    id_proveedor integer,
    clasificacion character varying(100),
    modelo character varying(100),
    capacidad numeric(10,4),
    id_unidad_medida integer,
    descripcion_presentacion character varying(300),
    costo_producto numeric(12,4) DEFAULT 0,
    costo_flete numeric(12,4) DEFAULT 0,
    porcentaje_margen numeric(6,2),
    precio_final numeric(12,4),
    precio_garantia numeric(12,4),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE pro_catalogo_precio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pro_catalogo_precio_id_seq OWNED BY public.pro_catalogo_precio.id;

ALTER TABLE pro_catalogo_precio ALTER COLUMN id SET DEFAULT nextval('public.pro_catalogo_precio_id_seq'::regclass);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_pkey PRIMARY KEY (id);

CREATE INDEX idx_pro_catalogo_nombre ON pro_catalogo_precio USING btree (nombre_item);

CREATE INDEX idx_pro_catalogo_precio ON pro_catalogo_precio USING btree (id_tipo_catalogo, periodo);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_tipo_balon_fkey FOREIGN KEY (id_tipo_balon) REFERENCES public.bal_tipo_balon(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_tipo_catalogo_fkey FOREIGN KEY (id_tipo_catalogo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE pro_catalogo_precio
    ADD CONSTRAINT pro_catalogo_precio_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
