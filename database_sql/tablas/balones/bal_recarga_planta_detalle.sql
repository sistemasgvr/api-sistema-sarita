-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_recarga_planta_detalle
-- Generated: 2026-09-02T21:43:34.270Z

CREATE TABLE bal_recarga_planta_detalle (
    id integer NOT NULL,
    id_recarga_planta integer NOT NULL,
    id_balon integer NOT NULL,
    id_producto integer,
    capacidad numeric(10,4),
    id_unidad_medida integer,
    lote character varying(50),
    fecha_vencimiento_lote date,
    fecha_prueba_hidrostatica date,
    id_movimiento_recarga integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_recarga_planta_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_recarga_planta_detalle_id_seq OWNED BY public.bal_recarga_planta_detalle.id;

ALTER TABLE bal_recarga_planta_detalle ALTER COLUMN id SET DEFAULT nextval('public.bal_recarga_planta_detalle_id_seq'::regclass);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_recarga_planta_id_balon_key UNIQUE (id_recarga_planta, id_balon);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_recarga_planta_det_balon ON bal_recarga_planta_detalle USING btree (id_balon);

CREATE INDEX idx_bal_recarga_planta_det_cab ON bal_recarga_planta_detalle USING btree (id_recarga_planta);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_movimiento_recarga_fkey FOREIGN KEY (id_movimiento_recarga) REFERENCES public.bal_movimiento_recarga(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_recarga_planta_fkey FOREIGN KEY (id_recarga_planta) REFERENCES public.bal_recarga_planta(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_recarga_planta_detalle
    ADD CONSTRAINT bal_recarga_planta_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
