-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_recojo
-- Generated: 2026-09-02T21:43:42.701Z

CREATE TABLE bal_recojo (
    id integer NOT NULL,
    id_cliente integer NOT NULL,
    id_prestamo integer,
    fecha_programada date NOT NULL,
    hora_estimada time without time zone,
    fecha_visita date,
    id_usuario_responsable integer,
    id_estado integer,
    id_motivo_fallo integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_alquiler integer,
    id_resultado_regulador integer,
    id_condicion_regulador integer,
    nueva_fecha_retorno_regulador date,
    observacion_regulador character varying(500),
    id_recarga_planta integer,
    id_compra integer
);

CREATE SEQUENCE bal_recojo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_recojo_id_seq OWNED BY public.bal_recojo.id;

ALTER TABLE bal_recojo ALTER COLUMN id SET DEFAULT nextval('public.bal_recojo_id_seq'::regclass);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_recojo_alquiler ON bal_recojo USING btree (id_alquiler);

CREATE INDEX idx_bal_recojo_cliente ON bal_recojo USING btree (id_cliente);

CREATE INDEX idx_bal_recojo_compra ON bal_recojo USING btree (id_compra);

CREATE INDEX idx_bal_recojo_estado ON bal_recojo USING btree (id_estado);

CREATE INDEX idx_bal_recojo_fecha ON bal_recojo USING btree (fecha_programada);

CREATE INDEX idx_bal_recojo_prestamo ON bal_recojo USING btree (id_prestamo);

CREATE INDEX idx_bal_recojo_recarga_planta ON bal_recojo USING btree (id_recarga_planta);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_condicion_regulador_fkey FOREIGN KEY (id_condicion_regulador) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_motivo_fallo_fkey FOREIGN KEY (id_motivo_fallo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_prestamo_fkey FOREIGN KEY (id_prestamo) REFERENCES public.bal_prestamo(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_recarga_planta_fkey FOREIGN KEY (id_recarga_planta) REFERENCES public.bal_recarga_planta(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_resultado_regulador_fkey FOREIGN KEY (id_resultado_regulador) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_recojo
    ADD CONSTRAINT bal_recojo_id_usuario_responsable_fkey FOREIGN KEY (id_usuario_responsable) REFERENCES public.auth_usuarios(id);
