CREATE TABLE ven_percepcion (
    id integer NOT NULL,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    fecha_emision date NOT NULL,
    id_empresa integer NOT NULL,
    id_cliente integer NOT NULL,
    id_sucursal integer,
    regimen character varying(5) NOT NULL,
    tasa numeric(8,4) NOT NULL,
    base_imponible numeric(12,4) DEFAULT 0 NOT NULL,
    monto_percibido numeric(12,4) DEFAULT 0 NOT NULL,
    monto_cobrado numeric(12,4) DEFAULT 0 NOT NULL,
    observacion character varying(500),
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_percepcion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_percepcion_id_seq OWNED BY public.ven_percepcion.id;

ALTER TABLE ven_percepcion ALTER COLUMN id SET DEFAULT nextval('public.ven_percepcion_id_seq'::regclass);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_pkey PRIMARY KEY (id);

-- Correlativo único por empresa + serie (cada RUC numera aparte en SUNAT).
ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);

CREATE INDEX idx_ven_percepcion_empresa ON ven_percepcion USING btree (id_empresa);

CREATE INDEX idx_ven_percepcion_cliente ON ven_percepcion USING btree (id_cliente);

CREATE INDEX idx_ven_percepcion_fecha ON ven_percepcion USING btree (fecha_emision);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);


ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
