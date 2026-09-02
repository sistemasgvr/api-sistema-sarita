-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_ruta_pueblo
-- Generated: 2026-09-02T21:43:59.341Z

CREATE TABLE bal_ruta_pueblo (
    id integer NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    id_almacen integer NOT NULL,
    id_usuario_responsable integer,
    id_chofer integer,
    factor_lb_m3 numeric(12,6) DEFAULT 0.317400 NOT NULL,
    tolerancia_m3 numeric(12,4) DEFAULT 0.5000 NOT NULL,
    m3_reportado_ventas numeric(12,4),
    m3_calculado numeric(12,4),
    descuadre_m3 numeric(12,4),
    id_estado integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_ruta_pueblo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_ruta_pueblo_id_seq OWNED BY public.bal_ruta_pueblo.id;

ALTER TABLE bal_ruta_pueblo ALTER COLUMN id SET DEFAULT nextval('public.bal_ruta_pueblo_id_seq'::regclass);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_ruta_pueblo_alm ON bal_ruta_pueblo USING btree (id_almacen);

CREATE INDEX idx_bal_ruta_pueblo_almacen ON bal_ruta_pueblo USING btree (id_almacen);

CREATE INDEX idx_bal_ruta_pueblo_estado ON bal_ruta_pueblo USING btree (id_estado);

CREATE INDEX idx_bal_ruta_pueblo_fecha ON bal_ruta_pueblo USING btree (fecha);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_chofer_fkey FOREIGN KEY (id_chofer) REFERENCES public.gen_chofer(id);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_ruta_pueblo
    ADD CONSTRAINT bal_ruta_pueblo_id_usuario_responsable_fkey FOREIGN KEY (id_usuario_responsable) REFERENCES public.auth_usuarios(id);
