-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_recojo_detalle
-- Generated: 2026-09-02T21:43:51.117Z

CREATE TABLE bal_recojo_detalle (
    id integer NOT NULL,
    id_recojo integer NOT NULL,
    id_prestamo_detalle integer,
    id_resultado integer,
    id_estado_contenido integer,
    nueva_fecha_retorno date,
    id_almacen_destino integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_alquiler_detalle integer,
    cantidad_restante numeric(10,4),
    id_balon integer,
    CONSTRAINT chk_bal_recojo_detalle_origen CHECK ((num_nonnulls(id_prestamo_detalle, id_alquiler_detalle, id_balon) = 1))
);

CREATE SEQUENCE bal_recojo_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_recojo_detalle_id_seq OWNED BY public.bal_recojo_detalle.id;

ALTER TABLE bal_recojo_detalle ALTER COLUMN id SET DEFAULT nextval('public.bal_recojo_detalle_id_seq'::regclass);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_recojo_det_ad ON bal_recojo_detalle USING btree (id_alquiler_detalle) WHERE (id_alquiler_detalle IS NOT NULL);

CREATE INDEX idx_bal_recojo_det_balon ON bal_recojo_detalle USING btree (id_balon);

CREATE INDEX idx_bal_recojo_det_cab ON bal_recojo_detalle USING btree (id_recojo);

CREATE INDEX idx_bal_recojo_det_pd ON bal_recojo_detalle USING btree (id_prestamo_detalle);

CREATE UNIQUE INDEX uq_bal_recojo_det_alquiler ON bal_recojo_detalle USING btree (id_recojo, id_alquiler_detalle) WHERE (id_alquiler_detalle IS NOT NULL);

CREATE UNIQUE INDEX uq_bal_recojo_detalle_alquiler ON bal_recojo_detalle USING btree (id_recojo, id_alquiler_detalle) WHERE (id_alquiler_detalle IS NOT NULL);

CREATE UNIQUE INDEX uq_bal_recojo_detalle_prestamo ON bal_recojo_detalle USING btree (id_recojo, id_prestamo_detalle) WHERE (id_prestamo_detalle IS NOT NULL);

CREATE UNIQUE INDEX uq_bal_recojo_detalle_unico ON bal_recojo_detalle USING btree (id_recojo, COALESCE(id_prestamo_detalle, id_alquiler_detalle), COALESCE(id_balon, 0));

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_almacen_destino_fkey FOREIGN KEY (id_almacen_destino) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_alquiler_detalle_fkey FOREIGN KEY (id_alquiler_detalle) REFERENCES public.bal_alquiler_detalle(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_estado_contenido_fkey FOREIGN KEY (id_estado_contenido) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_prestamo_detalle_fkey FOREIGN KEY (id_prestamo_detalle) REFERENCES public.bal_prestamo_detalle(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_recojo_fkey FOREIGN KEY (id_recojo) REFERENCES public.bal_recojo(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_resultado_fkey FOREIGN KEY (id_resultado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_recojo_detalle
    ADD CONSTRAINT bal_recojo_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
