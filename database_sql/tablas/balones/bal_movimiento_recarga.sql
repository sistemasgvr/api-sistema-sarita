-- Recargas de balones con producto, capacidad, guías y comprobante
CREATE TABLE public.bal_movimiento_recarga (
  id integer NOT NULL,
  fecha_salida_almacen date NOT NULL,
  id_balon integer NOT NULL,
  id_producto integer,
  capacidad numeric(10, 4),
  id_unidad_medida integer,
  serie_guia_salida character varying(10),
  numero_guia_salida character varying(15),
  serie_guia_ingreso character varying(10),
  numero_guia_ingreso character varying(15),
  serie_factura character varying(10),
  numero_factura character varying(15),
  id_comprobante integer,
  fecha_llegada_almacen date,
  lote character varying(50),
  fecha_vencimiento_lote date,
  fecha_prueba_hidrostatica date,
  id_proveedor integer,
  observacion character varying(500),
  id_almacen integer,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_cliente integer,
  id_tipo_recarga integer,
  id_balon_origen integer,
  id_comprobante_compra integer,
  id_doc_salida integer,
  id_lote_protocolo integer
);

CREATE SEQUENCE public.bal_movimiento_recarga_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_movimiento_recarga_id_seq OWNED BY public.bal_movimiento_recarga.id;

ALTER TABLE ONLY public.bal_movimiento_recarga
ALTER COLUMN id
SET DEFAULT nextval('public.bal_movimiento_recarga_id_seq'::regclass);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_mov_recarga_lote ON public.bal_movimiento_recarga USING btree (id_lote_protocolo);

CREATE INDEX idx_bal_movimiento_recarga_balon ON public.bal_movimiento_recarga USING btree (id_balon);

CREATE INDEX idx_bal_movimiento_recarga_cliente ON public.bal_movimiento_recarga USING btree (id_cliente);

CREATE INDEX idx_bal_movimiento_recarga_doc ON public.bal_movimiento_recarga USING btree (id_doc_salida);

CREATE INDEX idx_bal_movimiento_recarga_fecha ON public.bal_movimiento_recarga USING btree (fecha_salida_almacen);

CREATE INDEX idx_bal_recarga_compra ON public.bal_movimiento_recarga USING btree (id_comprobante_compra)
WHERE
  (id_comprobante_compra IS NOT NULL);

CREATE INDEX idx_bal_recarga_origen ON public.bal_movimiento_recarga USING btree (id_balon_origen)
WHERE
  (id_balon_origen IS NOT NULL);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_balon_origen_fkey FOREIGN KEY (id_balon_origen) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_comprobante_compra_fkey FOREIGN KEY (id_comprobante_compra) REFERENCES public.com_comprobante_compra (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_lote_protocolo_fkey FOREIGN KEY (id_lote_protocolo) REFERENCES public.bal_lote_protocolo (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_tipo_recarga_fkey FOREIGN KEY (id_tipo_recarga) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_movimiento_recarga
ADD CONSTRAINT bal_movimiento_recarga_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
