-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: age_actividad
-- Generated: 2026-09-09T16:16:48.728Z
CREATE TABLE age_actividad (
    id integer NOT NULL,
    titulo character varying(150) NOT NULL,
    descripcion text,
    fecha_programada date NOT NULL,
    hora_inicio_estimada time without time zone,
    hora_fin_estimada time without time zone,
    fecha_hora_cierre timestamp without time zone,
    id_tipo_actividad integer NOT NULL,
    id_prioridad integer NOT NULL,
    id_cliente integer,
    id_usuario_responsable integer,
    id_estado_actividad integer NOT NULL,
    observaciones character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_chofer_responsable integer,
    id_comprobante integer,
    id_trabajador_responsable integer,
    id_doc_salida integer,
    id_prestamo integer,
    id_tipo_origen integer,
    id_alquiler integer
);

CREATE SEQUENCE age_actividad_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE age_actividad_id_seq OWNED BY public.age_actividad.id;

ALTER TABLE age_actividad ALTER COLUMN id SET DEFAULT nextval('public.age_actividad_id_seq'::regclass);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_pkey PRIMARY KEY (id);

CREATE INDEX idx_age_actividad_chofer ON age_actividad USING btree (id_chofer_responsable) WHERE (id_chofer_responsable IS NOT NULL);

CREATE INDEX idx_age_actividad_comprobante ON age_actividad USING btree (id_comprobante) WHERE (id_comprobante IS NOT NULL);

CREATE INDEX idx_age_actividad_doc ON age_actividad USING btree (id_doc_salida);

CREATE INDEX idx_age_actividad_id_alquiler ON age_actividad USING btree (id_alquiler) WHERE (id_alquiler IS NOT NULL);

CREATE INDEX idx_age_actividad_prestamo ON age_actividad USING btree (id_prestamo);

CREATE INDEX idx_age_actividad_trabajador ON age_actividad USING btree (id_trabajador_responsable) WHERE (id_trabajador_responsable IS NOT NULL);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_chofer_responsable_fkey FOREIGN KEY (id_chofer_responsable) REFERENCES public.gen_chofer(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_estado_actividad_fkey FOREIGN KEY (id_estado_actividad) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_prestamo_fkey FOREIGN KEY (id_prestamo) REFERENCES public.bal_prestamo(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_prioridad_fkey FOREIGN KEY (id_prioridad) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_tipo_actividad_fkey FOREIGN KEY (id_tipo_actividad) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_tipo_origen_fkey FOREIGN KEY (id_tipo_origen) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_trabajador_responsable_fkey FOREIGN KEY (id_trabajador_responsable) REFERENCES public.tra_trabajadores(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE age_actividad
    ADD CONSTRAINT age_actividad_id_usuario_responsable_fkey FOREIGN KEY (id_usuario_responsable) REFERENCES public.auth_usuarios(id);
