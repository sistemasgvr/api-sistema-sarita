-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_movimiento_recarga_origen
-- Generated: 2026-09-02T21:43:00.788Z

CREATE TABLE bal_movimiento_recarga_origen (
    id integer NOT NULL,
    id_movimiento_recarga integer NOT NULL,
    id_balon integer NOT NULL,
    cantidad numeric(10,4) NOT NULL,
    orden integer DEFAULT 1 NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    fecha_creacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_movimiento_recarga_origen_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_movimiento_recarga_origen_id_seq OWNED BY public.bal_movimiento_recarga_origen.id;

ALTER TABLE bal_movimiento_recarga_origen ALTER COLUMN id SET DEFAULT nextval('public.bal_movimiento_recarga_origen_id_seq'::regclass);

ALTER TABLE bal_movimiento_recarga_origen
    ADD CONSTRAINT bal_movimiento_recarga_origen_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_mov_recarga_origen_mov ON bal_movimiento_recarga_origen USING btree (id_movimiento_recarga);

ALTER TABLE bal_movimiento_recarga_origen
    ADD CONSTRAINT bal_movimiento_recarga_origen_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_movimiento_recarga_origen
    ADD CONSTRAINT bal_movimiento_recarga_origen_id_movimiento_recarga_fkey FOREIGN KEY (id_movimiento_recarga) REFERENCES public.bal_movimiento_recarga(id);

ALTER TABLE bal_movimiento_recarga_origen
    ADD CONSTRAINT bal_movimiento_recarga_origen_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);
