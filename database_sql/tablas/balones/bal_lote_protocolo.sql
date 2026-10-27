-- Fichas de lote y protocolo de análisis del gas por proveedor
CREATE TABLE public.bal_lote_protocolo (
  id integer NOT NULL,
  numero_lote character varying(60) NOT NULL,
  numero_protocolo character varying(30),
  id_proveedor integer,
  id_producto_gas integer,
  descripcion_producto character varying(250),
  forma_farmaceutica character varying(80),
  presentacion character varying(150),
  norma_tecnica character varying(80),
  metodo_fabricacion character varying(150),
  fecha_analisis date,
  fecha_emision date,
  fecha_fabricacion date,
  fecha_vencimiento date,
  tamano_lote_m3 numeric(12, 2),
  cantidad_envases integer,
  valoracion_o2_pct numeric(6, 3),
  limite_co2_ppm numeric(10, 3),
  limite_co_ppm numeric(10, 3),
  cilindro_muestreado_serie character varying(60),
  temperatura_muestreo_c numeric(6, 2),
  presion_muestreo_psi numeric(10, 2),
  analista character varying(150),
  conclusion character varying(500),
  codigo_documento character varying(40),
  version_documento character varying(10),
  id_archivo_pdf integer,
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.bal_lote_protocolo_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_lote_protocolo_id_seq OWNED BY public.bal_lote_protocolo.id;

ALTER TABLE ONLY public.bal_lote_protocolo
ALTER COLUMN id
SET DEFAULT nextval('public.bal_lote_protocolo_id_seq'::regclass);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_lote_protocolo_gas ON public.bal_lote_protocolo USING btree (id_producto_gas);

CREATE INDEX idx_bal_lote_protocolo_numero ON public.bal_lote_protocolo USING btree (numero_lote);

CREATE INDEX idx_bal_lote_protocolo_proveedor ON public.bal_lote_protocolo USING btree (id_proveedor);

CREATE INDEX idx_bal_lote_protocolo_venc ON public.bal_lote_protocolo USING btree (fecha_vencimiento);

CREATE UNIQUE INDEX uq_bal_lote_protocolo_activo ON public.bal_lote_protocolo USING btree (numero_lote, COALESCE(id_proveedor, 0))
WHERE
  (estado = 1);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_id_archivo_pdf_fkey FOREIGN KEY (id_archivo_pdf) REFERENCES public.gen_archivo (id);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_id_producto_gas_fkey FOREIGN KEY (id_producto_gas) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes (id);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_lote_protocolo
ADD CONSTRAINT bal_lote_protocolo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
