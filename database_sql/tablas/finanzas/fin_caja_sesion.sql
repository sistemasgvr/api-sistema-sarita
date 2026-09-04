-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: fin_caja_sesion
-- Generated: 2026-09-02T21:45:40.588Z

CREATE TABLE fin_caja_sesion (
    id integer NOT NULL,
    fecha date NOT NULL,
    id_sucursal integer,
    id_estado integer NOT NULL,
    monto_inicial numeric(12,4) DEFAULT 0 NOT NULL,
    monto_efectivo_contado numeric(12,4),
    monto_esperado numeric(12,4),
    diferencia numeric(12,4),
    totales_cierre json,
    observacion_apertura character varying(500),
    observacion_cierre character varying(500),
    fecha_apertura timestamp without time zone DEFAULT now() NOT NULL,
    fecha_cierre timestamp without time zone,
    id_usuario_apertura integer,
    id_usuario_cierre integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE fin_caja_sesion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fin_caja_sesion_id_seq OWNED BY public.fin_caja_sesion.id;

ALTER TABLE fin_caja_sesion ALTER COLUMN id SET DEFAULT nextval('public.fin_caja_sesion_id_seq'::regclass);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_caja_sesion_estado ON fin_caja_sesion USING btree (id_estado);

CREATE INDEX idx_fin_caja_sesion_fecha ON fin_caja_sesion USING btree (fecha);

CREATE UNIQUE INDEX uq_fin_caja_sesion_fecha_sucursal ON fin_caja_sesion USING btree (fecha, COALESCE(id_sucursal, 0)) WHERE (estado = 1);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_usuario_apertura_fkey FOREIGN KEY (id_usuario_apertura) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_usuario_cierre_fkey FOREIGN KEY (id_usuario_cierre) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_caja_sesion
    ADD CONSTRAINT fin_caja_sesion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
