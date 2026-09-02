-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: pro_producto
-- Generated: 2026-09-02T21:50:00.908Z

CREATE TABLE pro_producto (
    id integer NOT NULL,
    codigo character varying(30) NOT NULL,
    codigo_barra character varying(50),
    nombre character varying(300) NOT NULL,
    id_sub_categoria integer,
    id_unidad_medida integer,
    marca character varying(100),
    presentacion character varying(150),
    es_gas boolean DEFAULT false,
    es_servicio boolean DEFAULT false,
    es_alquilable boolean DEFAULT false,
    afecta_stock boolean DEFAULT true,
    precio numeric(12,4) DEFAULT 0,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    codigo_ubicacion character varying(20),
    precio_compra numeric(12,4) DEFAULT 0,
    precio_garantia numeric(12,4) DEFAULT 0,
    factor_kg_m3 numeric(14,6),
    factor_lb_m3 numeric(14,6),
    es_mantenimiento boolean DEFAULT false NOT NULL
);

CREATE SEQUENCE pro_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE pro_producto_id_seq OWNED BY public.pro_producto.id;

ALTER TABLE pro_producto ALTER COLUMN id SET DEFAULT nextval('public.pro_producto_id_seq'::regclass);

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_codigo_key UNIQUE (codigo);

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX uq_pro_producto_codigo_ubicacion ON pro_producto USING btree (lower(TRIM(BOTH FROM codigo_ubicacion))) WHERE ((codigo_ubicacion IS NOT NULL) AND (TRIM(BOTH FROM codigo_ubicacion) <> ''::text));

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_id_sub_categoria_fkey FOREIGN KEY (id_sub_categoria) REFERENCES public.pro_sub_categoria(id);

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE pro_producto
    ADD CONSTRAINT pro_producto_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
