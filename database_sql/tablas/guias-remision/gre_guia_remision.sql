-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gre_guia_remision
-- Generated: 2026-09-02T21:49:10.069Z

CREATE TABLE gre_guia_remision (
    id integer NOT NULL,
    id_tipo_guia_remision integer,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    fecha date NOT NULL,
    tipo_cambio numeric(10,4) DEFAULT 3.5,
    id_sucursal integer NOT NULL,
    id_almacen integer NOT NULL,
    id_cliente integer,
    fecha_traslado date NOT NULL,
    id_motivo_traslado integer,
    id_unidad_medida integer,
    peso_bruto numeric(10,4),
    numero_bultos integer,
    direccion_origen character varying(255),
    id_distrito_origen integer,
    id_destinatario integer,
    direccion_llegada character varying(255),
    id_distrito_llegada integer,
    id_modalidad_traslado integer,
    id_transportista integer,
    id_chofer integer,
    id_vehiculo integer,
    id_responsable integer,
    observaciones character varying(500),
    periodo_contable character varying(10),
    operacion character varying(100),
    id_estado integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    destinatario_nombre character varying(255),
    destinatario_documento character varying(20),
    remitente_nombre character varying(255),
    remitente_documento character varying(20)
);

CREATE SEQUENCE gre_guia_remision_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gre_guia_remision_id_seq OWNED BY public.gre_guia_remision.id;

ALTER TABLE gre_guia_remision ALTER COLUMN id SET DEFAULT nextval('public.gre_guia_remision_id_seq'::regclass);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_pkey PRIMARY KEY (id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_serie_numero_key UNIQUE (serie, numero);

CREATE INDEX idx_gre_cliente ON gre_guia_remision USING btree (id_cliente);

CREATE INDEX idx_gre_fecha ON gre_guia_remision USING btree (fecha);

CREATE INDEX idx_gre_serie ON gre_guia_remision USING btree (serie, numero);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_chofer_fkey FOREIGN KEY (id_chofer) REFERENCES public.gen_chofer(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_destinatario_fkey FOREIGN KEY (id_destinatario) REFERENCES public.cli_clientes(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_distrito_llegada_fkey FOREIGN KEY (id_distrito_llegada) REFERENCES public.gen_distrito(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_distrito_origen_fkey FOREIGN KEY (id_distrito_origen) REFERENCES public.gen_distrito(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_modalidad_traslado_fkey FOREIGN KEY (id_modalidad_traslado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_motivo_traslado_fkey FOREIGN KEY (id_motivo_traslado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_responsable_fkey FOREIGN KEY (id_responsable) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_tipo_guia_remision_fkey FOREIGN KEY (id_tipo_guia_remision) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_transportista_fkey FOREIGN KEY (id_transportista) REFERENCES public.cli_clientes(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_guia_remision
    ADD CONSTRAINT gre_guia_remision_id_vehiculo_fkey FOREIGN KEY (id_vehiculo) REFERENCES public.gen_vehiculo(id);
