-- Garantías cobradas a clientes por préstamos o alquileres con su saldo
CREATE TABLE public.ven_garantia (
  id integer NOT NULL,
  id_cliente integer NOT NULL,
  id_prestamo integer,
  ubicacion character varying(150),
  id_producto integer,
  cantidad_venta numeric(12, 4),
  id_unidad_medida integer,
  fecha_registro date NOT NULL,
  monto_cobrado numeric(12, 4) DEFAULT 0 NOT NULL,
  monto_devuelto numeric(12, 4) DEFAULT 0 NOT NULL,
  monto_saldo numeric(12, 4) DEFAULT 0 NOT NULL,
  id_estado integer,
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_alquiler integer,
  id_medio_pago integer,
  fecha_reembolso date,
  id_medio_reembolso integer,
  observacion_reembolso character varying(500),
  id_usuario_reembolso integer,
  id_cuenta_bancaria integer,
  id_cuenta_bancaria_reembolso integer,
  id_prestamo_detalle integer,
  id_garantia_origen integer,
  monto_transferido numeric(12, 4) DEFAULT 0 NOT NULL
);

COMMENT ON COLUMN public.ven_garantia.id_alquiler IS 'Alquiler asociado a la garantía (opcional)';

COMMENT ON COLUMN public.ven_garantia.id_medio_pago IS 'Método con el que se recibió la garantía (sobre todo manuales)';

COMMENT ON COLUMN public.ven_garantia.fecha_reembolso IS 'Fecha del último reembolso total (DEVUELTA)';

COMMENT ON COLUMN public.ven_garantia.id_medio_reembolso IS 'Método usado al devolver/reembolsar';

COMMENT ON COLUMN public.ven_garantia.observacion_reembolso IS 'Observación del reembolso (espejo fin_garantia)';

CREATE SEQUENCE public.ven_garantia_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_garantia_id_seq OWNED BY public.ven_garantia.id;

ALTER TABLE ONLY public.ven_garantia
ALTER COLUMN id
SET DEFAULT nextval('public.ven_garantia_id_seq'::regclass);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_garantia_cliente ON public.ven_garantia USING btree (id_cliente);

CREATE INDEX idx_ven_garantia_fecha ON public.ven_garantia USING btree (fecha_registro);

CREATE INDEX idx_ven_garantia_origen ON public.ven_garantia USING btree (id_garantia_origen)
WHERE
  (id_garantia_origen IS NOT NULL);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_cuenta_bancaria_reembolso_fkey FOREIGN KEY (id_cuenta_bancaria_reembolso) REFERENCES public.gen_cuenta_bancaria (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_garantia_origen_fkey FOREIGN KEY (id_garantia_origen) REFERENCES public.ven_garantia (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_medio_reembolso_fkey FOREIGN KEY (id_medio_reembolso) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_prestamo_detalle_fkey FOREIGN KEY (id_prestamo_detalle) REFERENCES public.bal_prestamo_detalle (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_prestamo_fkey FOREIGN KEY (id_prestamo) REFERENCES public.bal_prestamo (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.ven_garantia
ADD CONSTRAINT ven_garantia_id_usuario_reembolso_fkey FOREIGN KEY (id_usuario_reembolso) REFERENCES public.auth_usuarios (id);
