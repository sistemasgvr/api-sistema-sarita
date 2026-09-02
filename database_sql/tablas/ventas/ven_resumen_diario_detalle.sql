-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_resumen_diario_detalle
-- Generated: 2026-09-02T21:51:33.295Z

CREATE TABLE ven_resumen_diario_detalle (
    id integer NOT NULL,
    id_resumen integer NOT NULL,
    id_comprobante integer NOT NULL,
    item integer NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_resumen_diario_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_resumen_diario_detalle_id_seq OWNED BY public.ven_resumen_diario_detalle.id;

ALTER TABLE ven_resumen_diario_detalle ALTER COLUMN id SET DEFAULT nextval('public.ven_resumen_diario_detalle_id_seq'::regclass);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_id_resumen_id_comprobante_key UNIQUE (id_resumen, id_comprobante);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_resumen_detalle_comprobante ON ven_resumen_diario_detalle USING btree (id_comprobante);

CREATE INDEX idx_ven_resumen_detalle_resumen ON ven_resumen_diario_detalle USING btree (id_resumen);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_id_resumen_fkey FOREIGN KEY (id_resumen) REFERENCES public.ven_resumen_diario(id);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_resumen_diario_detalle
    ADD CONSTRAINT ven_resumen_diario_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
