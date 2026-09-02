-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_ruta_pueblo_detalle
-- Generated: 2026-09-02T21:44:07.716Z

CREATE TABLE bal_ruta_pueblo_detalle (
    id integer NOT NULL,
    id_ruta_pueblo integer NOT NULL,
    id_balon integer NOT NULL,
    sellado boolean DEFAULT false NOT NULL,
    lb_salida numeric(12,4) NOT NULL,
    lb_retorno numeric(12,4),
    m3_delta numeric(12,4),
    capacidad_restante_m3 numeric(12,4),
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_ruta_pueblo_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_ruta_pueblo_detalle_id_seq OWNED BY public.bal_ruta_pueblo_detalle.id;

ALTER TABLE bal_ruta_pueblo_detalle ALTER COLUMN id SET DEFAULT nextval('public.bal_ruta_pueblo_detalle_id_seq'::regclass);

ALTER TABLE bal_ruta_pueblo_detalle
    ADD CONSTRAINT bal_ruta_pueblo_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_ruta_pueblo_det_balon ON bal_ruta_pueblo_detalle USING btree (id_balon);

CREATE INDEX idx_bal_ruta_pueblo_det_cab ON bal_ruta_pueblo_detalle USING btree (id_ruta_pueblo);

CREATE UNIQUE INDEX uq_bal_ruta_pueblo_det_balon_activo ON bal_ruta_pueblo_detalle USING btree (id_ruta_pueblo, id_balon) WHERE (estado = 1);

CREATE UNIQUE INDEX uq_bal_ruta_pueblo_detalle_activo ON bal_ruta_pueblo_detalle USING btree (id_ruta_pueblo, id_balon) WHERE (estado = 1);

ALTER TABLE bal_ruta_pueblo_detalle
    ADD CONSTRAINT bal_ruta_pueblo_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_ruta_pueblo_detalle
    ADD CONSTRAINT bal_ruta_pueblo_detalle_id_ruta_pueblo_fkey FOREIGN KEY (id_ruta_pueblo) REFERENCES public.bal_ruta_pueblo(id);

ALTER TABLE bal_ruta_pueblo_detalle
    ADD CONSTRAINT bal_ruta_pueblo_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_ruta_pueblo_detalle
    ADD CONSTRAINT bal_ruta_pueblo_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
