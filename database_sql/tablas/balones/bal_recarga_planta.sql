-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_recarga_planta
-- Generated: 2026-09-02T21:43:25.879Z

CREATE TABLE bal_recarga_planta (
    id integer NOT NULL,
    numero character varying(30),
    fecha_salida date NOT NULL,
    id_proveedor integer,
    id_almacen integer,
    id_guia_salida integer,
    serie_guia_salida character varying(10),
    numero_guia_salida character varying(15),
    id_guia_retorno integer,
    serie_guia_ingreso character varying(10),
    numero_guia_ingreso character varying(15),
    id_comprobante_compra integer,
    serie_factura character varying(10),
    numero_factura character varying(15),
    fecha_llegada_almacen date,
    lote character varying(50),
    fecha_vencimiento_lote date,
    fecha_prueba_hidrostatica date,
    id_estado integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_recarga_planta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_recarga_planta_id_seq OWNED BY public.bal_recarga_planta.id;

ALTER TABLE bal_recarga_planta ALTER COLUMN id SET DEFAULT nextval('public.bal_recarga_planta_id_seq'::regclass);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_numero_key UNIQUE (numero);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_recarga_planta_fecha ON bal_recarga_planta USING btree (fecha_salida);

CREATE INDEX idx_bal_recarga_planta_guia_salida ON bal_recarga_planta USING btree (id_guia_salida);

CREATE INDEX idx_bal_recarga_planta_proveedor ON bal_recarga_planta USING btree (id_proveedor);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_guia_retorno_fkey FOREIGN KEY (id_guia_retorno) REFERENCES public.gre_guia_remision(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_guia_salida_fkey FOREIGN KEY (id_guia_salida) REFERENCES public.gre_guia_remision(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_recarga_planta
    ADD CONSTRAINT bal_recarga_planta_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
