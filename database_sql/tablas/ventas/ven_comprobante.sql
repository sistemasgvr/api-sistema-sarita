-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_comprobante
-- Generated: 2026-09-02T21:50:42.780Z

CREATE TABLE ven_comprobante (
    id integer NOT NULL,
    id_tipo_comprobante integer,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    id_estado_sunat integer,
    id_tipo_operacion_sunat integer,
    id_comprobante_origen integer,
    id_motivo_nota integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    id_tipo_movimiento integer,
    id_tipo_venta integer,
    fecha date NOT NULL,
    fecha_vencimiento date,
    tipo_cambio numeric(10,4) DEFAULT 3.5,
    id_cliente integer NOT NULL,
    id_sucursal integer,
    id_almacen integer,
    id_condicion_pago integer,
    id_moneda integer,
    id_medio_pago integer,
    sub_total numeric(12,4) DEFAULT 0,
    descuento numeric(12,4) DEFAULT 0,
    valor_venta numeric(12,4) DEFAULT 0,
    igv numeric(12,4) DEFAULT 0,
    total_importe numeric(12,4) DEFAULT 0,
    anticipos numeric(12,4) DEFAULT 0,
    exonerado numeric(12,4) DEFAULT 0,
    glosa character varying(500),
    observaciones character varying(500),
    periodo_contable character varying(10),
    operacion character varying(100),
    id_estado integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    origen_pos character varying(30)
);

CREATE SEQUENCE ven_comprobante_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_comprobante_id_seq OWNED BY public.ven_comprobante.id;

ALTER TABLE ven_comprobante ALTER COLUMN id SET DEFAULT nextval('public.ven_comprobante_id_seq'::regclass);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_pkey PRIMARY KEY (id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_serie_numero_key UNIQUE (serie, numero);

CREATE INDEX idx_ven_comprobante_cliente ON ven_comprobante USING btree (id_cliente);

CREATE INDEX idx_ven_comprobante_fecha ON ven_comprobante USING btree (fecha);

CREATE INDEX idx_ven_comprobante_serie ON ven_comprobante USING btree (serie, numero);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_comprobante_origen_fkey FOREIGN KEY (id_comprobante_origen) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_condicion_pago_fkey FOREIGN KEY (id_condicion_pago) REFERENCES public.gen_condicion_pago(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_moneda_fkey FOREIGN KEY (id_moneda) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_motivo_nota_fkey FOREIGN KEY (id_motivo_nota) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_tipo_comprobante_fkey FOREIGN KEY (id_tipo_comprobante) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_tipo_movimiento_fkey FOREIGN KEY (id_tipo_movimiento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_tipo_operacion_sunat_fkey FOREIGN KEY (id_tipo_operacion_sunat) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_tipo_venta_fkey FOREIGN KEY (id_tipo_venta) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_comprobante
    ADD CONSTRAINT ven_comprobante_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
