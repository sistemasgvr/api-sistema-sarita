-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: doc_salida
-- Generated: 2026-09-03T16:49:02.967Z
--
-- ⚠️ direccion_entrega/referencia_entrega/latitud/longitud/id_distrito_entrega/
-- id_direccion_cliente están pendientes de aplicar — ver
-- database_sql/migraciones/20260904_doc_salida_direccion_entrega.sql.
-- Volver a sincronizar este archivo con sync-tables-from-dev.js una vez aplicada.

CREATE TABLE doc_salida (
    id integer NOT NULL,
    numero character varying(30) NOT NULL,
    id_tipo_orden integer NOT NULL,
    id_estado_ciclo integer NOT NULL,
    emitido_sunat boolean DEFAULT false NOT NULL,
    id_venta integer,
    id_doc_salida_origen integer,
    id_sucursal integer NOT NULL,
    id_almacen integer NOT NULL,
    id_cliente integer,
    id_destinatario integer,
    id_proveedor integer,
    fecha date NOT NULL,
    fecha_traslado date,
    fecha_retorno date,
    id_tipo_guia_remision integer,
    serie character varying(10),
    numero_sunat character varying(15),
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    tipo_cambio numeric(10,4) DEFAULT 3.5,
    id_motivo_traslado integer,
    id_modalidad_traslado integer,
    id_unidad_medida integer,
    peso_bruto numeric(10,4),
    numero_bultos integer,
    direccion_origen character varying(255),
    id_distrito_origen integer,
    direccion_llegada character varying(255),
    id_distrito_llegada integer,
    id_transportista integer,
    id_chofer integer,
    id_vehiculo integer,
    id_responsable integer,
    destinatario_nombre character varying(255),
    destinatario_documento character varying(20),
    remitente_nombre character varying(255),
    remitente_documento character varying(20),
    id_comprobante_compra integer,
    serie_guia_salida character varying(10),
    numero_guia_salida character varying(15),
    serie_guia_ingreso character varying(10),
    numero_guia_ingreso character varying(15),
    serie_factura character varying(10),
    numero_factura character varying(15),
    fecha_llegada_almacen date,
    lote character varying(50),
    fecha_vencimiento_lote date,
    fecha_prueba_hidrostatica date,
    periodo_contable character varying(10),
    operacion character varying(100),
    observaciones character varying(500),
    id_archivo_pdf integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp without time zone
);

CREATE SEQUENCE doc_salida_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE doc_salida_id_seq OWNED BY public.doc_salida.id;

ALTER TABLE doc_salida ALTER COLUMN id SET DEFAULT nextval('public.doc_salida_id_seq'::regclass);

ALTER TABLE doc_salida
    ADD CONSTRAINT chk_doc_salida_sunat CHECK (((emitido_sunat = false) OR ((serie IS NOT NULL) AND (numero_sunat IS NOT NULL))));

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_pkey PRIMARY KEY (id);

CREATE INDEX idx_doc_salida_compra ON public.doc_salida USING btree (id_comprobante_compra);

CREATE INDEX idx_doc_salida_sucursal_fecha ON public.doc_salida USING btree (id_sucursal, fecha);

CREATE INDEX idx_doc_salida_tipo_estado ON public.doc_salida USING btree (id_tipo_orden, id_estado_ciclo);

CREATE INDEX idx_doc_salida_venta ON public.doc_salida USING btree (id_venta);

CREATE UNIQUE INDEX uq_doc_salida_numero ON public.doc_salida USING btree (numero) WHERE (estado = 1);

CREATE UNIQUE INDEX uq_doc_salida_serie_numero ON public.doc_salida USING btree (serie, numero_sunat) WHERE ((serie IS NOT NULL) AND (numero_sunat IS NOT NULL) AND (estado = 1));

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_archivo_pdf_fkey FOREIGN KEY (id_archivo_pdf) REFERENCES public.gen_archivo(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_chofer_fkey FOREIGN KEY (id_chofer) REFERENCES public.gen_chofer(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_destinatario_fkey FOREIGN KEY (id_destinatario) REFERENCES public.cli_clientes(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_distrito_llegada_fkey FOREIGN KEY (id_distrito_llegada) REFERENCES public.gen_distrito(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_distrito_origen_fkey FOREIGN KEY (id_distrito_origen) REFERENCES public.gen_distrito(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_doc_salida_origen_fkey FOREIGN KEY (id_doc_salida_origen) REFERENCES public.doc_salida(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_estado_ciclo_fkey FOREIGN KEY (id_estado_ciclo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_modalidad_traslado_fkey FOREIGN KEY (id_modalidad_traslado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_motivo_traslado_fkey FOREIGN KEY (id_motivo_traslado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_responsable_fkey FOREIGN KEY (id_responsable) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_tipo_guia_remision_fkey FOREIGN KEY (id_tipo_guia_remision) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_tipo_orden_fkey FOREIGN KEY (id_tipo_orden) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_transportista_fkey FOREIGN KEY (id_transportista) REFERENCES public.cli_clientes(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_vehiculo_fkey FOREIGN KEY (id_vehiculo) REFERENCES public.gen_vehiculo(id);

ALTER TABLE doc_salida
    ADD CONSTRAINT doc_salida_id_venta_fkey FOREIGN KEY (id_venta) REFERENCES public.ven_comprobante(id);
