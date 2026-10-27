-- Líneas de un comprobante de compra con producto, cantidad e importe
CREATE TABLE public.com_comprobante_compra_detalle (
  id integer NOT NULL,
  id_comprobante integer NOT NULL,
  item integer NOT NULL,
  id_clasificacion_gasto integer,
  id_producto integer,
  descripcion character varying(300) NOT NULL,
  id_unidad_medida integer,
  cantidad numeric(12, 4) NOT NULL,
  precio_unitario numeric(12, 6),
  importe numeric(12, 4) NOT NULL,
  id_medio_pago integer,
  fecha_pago date,
  numero_operacion character varying(50),
  id_estado_pago integer,
  observacion character varying(500),
  afecta_stock boolean DEFAULT FALSE,
  id_pago integer,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_almacen integer
);

CREATE SEQUENCE public.com_comprobante_compra_detalle_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.com_comprobante_compra_detalle_id_seq OWNED BY public.com_comprobante_compra_detalle.id;

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ALTER COLUMN id
SET DEFAULT nextval(
  'public.com_comprobante_compra_detalle_id_seq'::regclass
);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_clasificacion_gasto_fkey FOREIGN KEY (id_clasificacion_gasto) REFERENCES public.gen_clasificacion_gasto (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.com_comprobante_compra (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_estado_pago_fkey FOREIGN KEY (id_estado_pago) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_pago_fkey FOREIGN KEY (id_pago) REFERENCES public.fin_pago (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.com_comprobante_compra_detalle
ADD CONSTRAINT com_comprobante_compra_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
