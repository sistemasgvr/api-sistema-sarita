-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_alquiler_detalle
-- Generated: 2026-09-02T21:41:53.434Z

CREATE TABLE bal_alquiler_detalle (
    id integer NOT NULL,
    id_alquiler integer NOT NULL,
    id_balon integer NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    fecha_devolucion date
);

CREATE SEQUENCE bal_alquiler_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_alquiler_detalle_id_seq OWNED BY public.bal_alquiler_detalle.id;

ALTER TABLE bal_alquiler_detalle ALTER COLUMN id SET DEFAULT nextval('public.bal_alquiler_detalle_id_seq'::regclass);

ALTER TABLE bal_alquiler_detalle
    ADD CONSTRAINT bal_alquiler_detalle_pkey PRIMARY KEY (id);

ALTER TABLE bal_alquiler_detalle
    ADD CONSTRAINT bal_alquiler_detalle_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler(id);

ALTER TABLE bal_alquiler_detalle
    ADD CONSTRAINT bal_alquiler_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_alquiler_detalle
    ADD CONSTRAINT bal_alquiler_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_alquiler_detalle
    ADD CONSTRAINT bal_alquiler_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
