-- Comprobantes de compra con proveedor, totales, condición de pago y sucursal
CREATE TABLE public.com_comprobante_compra (
  id integer NOT NULL,
  id_tipo_comprobante integer,
  serie character varying(10),
  numero character varying(15),
  fecha date NOT NULL,
  id_proveedor integer,
  id_tipo_registro integer,
  id_categoria_gasto integer,
  id_sucursal integer,
  id_almacen integer,
  id_moneda integer,
  id_condicion_pago integer,
  sub_total numeric(12, 4) DEFAULT 0,
  igv numeric(12, 4) DEFAULT 0,
  total_importe numeric(12, 4) DEFAULT 0,
  afecta_inventario boolean DEFAULT FALSE,
  declarar_sunat boolean DEFAULT FALSE,
  glosa character varying(500),
  id_estado integer,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_comprobante_referencia integer,
  id_doc_salida integer,
  id_medio_pago integer,
  id_cuenta_bancaria integer,
  numero_operacion character varying(80),
  porcentaje_igv numeric(5, 2) DEFAULT 18 NOT NULL
);

CREATE SEQUENCE public.com_comprobante_compra_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.com_comprobante_compra_id_seq OWNED BY public.com_comprobante_compra.id;

ALTER TABLE ONLY public.com_comprobante_compra
ALTER COLUMN id
SET DEFAULT nextval('public.com_comprobante_compra_id_seq'::regclass);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_porcentaje_igv_check CHECK (
  porcentaje_igv >= 0
  AND porcentaje_igv <= 100
);

CREATE INDEX idx_com_compra_declarar_sunat ON public.com_comprobante_compra USING btree (declarar_sunat, fecha);

CREATE INDEX idx_com_compra_doc ON public.com_comprobante_compra USING btree (id_doc_salida);

CREATE INDEX idx_com_compra_fecha ON public.com_comprobante_compra USING btree (fecha);

CREATE INDEX idx_com_compra_proveedor ON public.com_comprobante_compra USING btree (id_proveedor);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_categoria_gasto_fkey FOREIGN KEY (id_categoria_gasto) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_comprobante_referencia_fkey FOREIGN KEY (id_comprobante_referencia) REFERENCES public.com_comprobante_compra (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_condicion_pago_fkey FOREIGN KEY (id_condicion_pago) REFERENCES public.gen_condicion_pago (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_moneda_fkey FOREIGN KEY (id_moneda) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_tipo_comprobante_fkey FOREIGN KEY (id_tipo_comprobante) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_tipo_registro_fkey FOREIGN KEY (id_tipo_registro) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.com_comprobante_compra
ADD CONSTRAINT com_comprobante_compra_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
