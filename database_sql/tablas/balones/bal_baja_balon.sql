-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_baja_balon
-- Generated: 2026-09-02T21:42:10.261Z

CREATE TABLE bal_baja_balon (
    id integer NOT NULL,
    id_balon integer NOT NULL,
    id_motivo_baja integer NOT NULL,
    fecha_baja date DEFAULT CURRENT_DATE NOT NULL,
    id_usuario_solicita integer NOT NULL,
    id_usuario_autoriza integer,
    fecha_autorizacion timestamp without time zone DEFAULT now(),
    motivo_detalle character varying(500),
    id_cliente_comprador integer,
    id_comprobante_venta integer,
    serie_comprobante character varying(10),
    numero_comprobante character varying(15),
    monto_venta numeric(12,4),
    id_movimiento integer,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    estado_aprobacion character varying(200) DEFAULT 'APROBADA'::character varying NOT NULL
);

CREATE SEQUENCE bal_baja_balon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_baja_balon_id_seq OWNED BY public.bal_baja_balon.id;

ALTER TABLE bal_baja_balon ALTER COLUMN id SET DEFAULT nextval('public.bal_baja_balon_id_seq'::regclass);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_pkey PRIMARY KEY (id);

CREATE UNIQUE INDEX idx_bal_baja_balon_aprobada ON bal_baja_balon USING btree (id_balon) WHERE ((estado = 1) AND ((estado_aprobacion)::text = 'APROBADA'::text));

CREATE INDEX idx_bal_baja_balon_balon ON bal_baja_balon USING btree (id_balon);

CREATE UNIQUE INDEX idx_bal_baja_balon_pendiente ON bal_baja_balon USING btree (id_balon) WHERE ((estado = 1) AND ((estado_aprobacion)::text = 'PENDIENTE'::text));

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_cliente_comprador_fkey FOREIGN KEY (id_cliente_comprador) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_comprobante_venta_fkey FOREIGN KEY (id_comprobante_venta) REFERENCES public.ven_comprobante(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_motivo_baja_fkey FOREIGN KEY (id_motivo_baja) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_usuario_autoriza_fkey FOREIGN KEY (id_usuario_autoriza) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_baja_balon
    ADD CONSTRAINT bal_baja_balon_id_usuario_solicita_fkey FOREIGN KEY (id_usuario_solicita) REFERENCES public.auth_usuarios(id);
