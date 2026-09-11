-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_balon_ph_historial
-- Generated: 2026-09-02T21:42:35.580Z
--
-- ⚠️ id_doc_salida está pendiente de aplicar — ver
-- database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql.

CREATE TABLE bal_balon_ph_historial (
    id integer NOT NULL,
    id_balon integer NOT NULL,
    fecha_prueba date NOT NULL,
    vigencia_anios integer DEFAULT 5 NOT NULL,
    fecha_proxima date,
    id_organo_inspector integer,
    organo_inspector_no_aplica boolean DEFAULT false NOT NULL,
    numero_certificado character varying(50),
    id_mantenimiento integer,
    id_movimiento_recarga integer,
    -- Orden de salida (recarga en planta externa) que trajo la prueba: es el
    -- tercer origen posible de una P.H., junto a mantenimiento y recarga propia.
    id_doc_salida integer,
    es_vigente boolean DEFAULT true NOT NULL,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE bal_balon_ph_historial_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_balon_ph_historial_id_seq OWNED BY public.bal_balon_ph_historial.id;

ALTER TABLE bal_balon_ph_historial ALTER COLUMN id SET DEFAULT nextval('public.bal_balon_ph_historial_id_seq'::regclass);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_balon_ph_historial_balon ON bal_balon_ph_historial USING btree (id_balon);

CREATE INDEX idx_bal_balon_ph_historial_vigente ON bal_balon_ph_historial USING btree (id_balon, es_vigente) WHERE (es_vigente = true);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_mantenimiento_fkey FOREIGN KEY (id_mantenimiento) REFERENCES public.bal_mantenimiento(id);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_movimiento_recarga_fkey FOREIGN KEY (id_movimiento_recarga) REFERENCES public.bal_movimiento_recarga(id);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida(id);

-- Una sola fila de historial por (orden de salida, cilindro): hace idempotente
-- a bal_sync_ph_desde_orden_salida si el retorno se reenvía o se corrige.
CREATE UNIQUE INDEX uq_bal_ph_historial_doc_salida_balon
    ON bal_balon_ph_historial USING btree (id_doc_salida, id_balon)
    WHERE ((id_doc_salida IS NOT NULL) AND (estado = 1));

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_organo_inspector_fkey FOREIGN KEY (id_organo_inspector) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_balon_ph_historial
    ADD CONSTRAINT bal_balon_ph_historial_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
