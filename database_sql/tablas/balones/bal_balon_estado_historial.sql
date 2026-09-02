-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_balon_estado_historial
-- Generated: 2026-09-02T21:42:27.318Z

CREATE TABLE bal_balon_estado_historial (
    id integer NOT NULL,
    id_balon integer NOT NULL,
    tipo_evento character varying(30) NOT NULL,
    id_baja integer,
    id_motivo_baja integer,
    id_estado_anterior integer,
    id_estado_nuevo integer,
    observacion character varying(500),
    id_usuario integer,
    fecha_evento timestamp without time zone DEFAULT now() NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    CONSTRAINT chk_bal_estado_historial_tipo CHECK (((tipo_evento)::text = ANY (ARRAY[('SOLICITUD_BAJA'::character varying)::text, ('BAJA_APROBADA'::character varying)::text, ('BAJA_RECHAZADA'::character varying)::text, ('REACTIVACION'::character varying)::text])))
);

CREATE SEQUENCE bal_balon_estado_historial_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_balon_estado_historial_id_seq OWNED BY public.bal_balon_estado_historial.id;

ALTER TABLE bal_balon_estado_historial ALTER COLUMN id SET DEFAULT nextval('public.bal_balon_estado_historial_id_seq'::regclass);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_estado_historial_balon ON bal_balon_estado_historial USING btree (id_balon, fecha_evento DESC);

CREATE INDEX idx_bal_estado_historial_tipo ON bal_balon_estado_historial USING btree (tipo_evento);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_baja_fkey FOREIGN KEY (id_baja) REFERENCES public.bal_baja_balon(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_estado_anterior_fkey FOREIGN KEY (id_estado_anterior) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_estado_nuevo_fkey FOREIGN KEY (id_estado_nuevo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_motivo_baja_fkey FOREIGN KEY (id_motivo_baja) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_balon_estado_historial
    ADD CONSTRAINT bal_balon_estado_historial_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
