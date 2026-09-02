-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_garantia_movimiento
-- Generated: 2026-09-02T21:51:16.445Z

CREATE TABLE ven_garantia_movimiento (
    id integer NOT NULL,
    id_garantia integer NOT NULL,
    id_tipo_movimiento integer NOT NULL,
    id_comprobante integer,
    fecha date NOT NULL,
    monto numeric(12,4) NOT NULL,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_sucursal integer,
    id_medio_pago integer
);

CREATE SEQUENCE ven_garantia_movimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_garantia_movimiento_id_seq OWNED BY public.ven_garantia_movimiento.id;

ALTER TABLE ven_garantia_movimiento ALTER COLUMN id SET DEFAULT nextval('public.ven_garantia_movimiento_id_seq'::regclass);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_garantia_mov ON ven_garantia_movimiento USING btree (id_garantia);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_garantia_fkey FOREIGN KEY (id_garantia) REFERENCES public.ven_garantia(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_tipo_movimiento_fkey FOREIGN KEY (id_tipo_movimiento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_garantia_movimiento
    ADD CONSTRAINT ven_garantia_movimiento_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
