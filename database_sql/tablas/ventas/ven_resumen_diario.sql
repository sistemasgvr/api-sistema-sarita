-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_resumen_diario
-- Generated: 2026-09-02T21:51:24.887Z

CREATE TABLE ven_resumen_diario (
    id integer NOT NULL,
    fecha date NOT NULL,
    correlativo character varying(10) NOT NULL,
    identificador character varying(50),
    ticket_sunat character varying(100),
    id_estado_sunat integer,
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    moneda character varying(3) DEFAULT 'PEN'::character varying,
    cantidad_docs integer DEFAULT 0 NOT NULL,
    total_importe numeric(12,4) DEFAULT 0 NOT NULL,
    total_igv numeric(12,4) DEFAULT 0 NOT NULL,
    total_valor_venta numeric(12,4) DEFAULT 0 NOT NULL,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_resumen_diario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_resumen_diario_id_seq OWNED BY public.ven_resumen_diario.id;

ALTER TABLE ven_resumen_diario ALTER COLUMN id SET DEFAULT nextval('public.ven_resumen_diario_id_seq'::regclass);

ALTER TABLE ven_resumen_diario
    ADD CONSTRAINT ven_resumen_diario_fecha_correlativo_key UNIQUE (fecha, correlativo);

ALTER TABLE ven_resumen_diario
    ADD CONSTRAINT ven_resumen_diario_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_resumen_diario_estado_sunat ON ven_resumen_diario USING btree (id_estado_sunat);

CREATE INDEX idx_ven_resumen_diario_fecha ON ven_resumen_diario USING btree (fecha);

CREATE INDEX idx_ven_resumen_diario_ticket ON ven_resumen_diario USING btree (ticket_sunat);

ALTER TABLE ven_resumen_diario
    ADD CONSTRAINT ven_resumen_diario_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_resumen_diario
    ADD CONSTRAINT ven_resumen_diario_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_resumen_diario
    ADD CONSTRAINT ven_resumen_diario_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
