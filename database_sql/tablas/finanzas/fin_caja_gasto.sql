-- Gastos pagados en una sesión de caja
CREATE TABLE public.fin_caja_gasto (
  id integer NOT NULL,
  id_sesion integer,
  fecha date NOT NULL,
  concepto character varying(200) NOT NULL,
  monto numeric(12, 4) NOT NULL,
  id_medio_pago integer,
  id_categoria_gasto integer,
  numero_operacion character varying(80),
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_cuenta_bancaria integer,
  CONSTRAINT fin_caja_gasto_monto_check CHECK ((monto > (0)::numeric))
);

CREATE SEQUENCE public.fin_caja_gasto_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.fin_caja_gasto_id_seq OWNED BY public.fin_caja_gasto.id;

ALTER TABLE ONLY public.fin_caja_gasto
ALTER COLUMN id
SET DEFAULT nextval('public.fin_caja_gasto_id_seq'::regclass);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_caja_gasto_cuenta ON public.fin_caja_gasto USING btree (id_cuenta_bancaria)
WHERE
  (estado = 1);

CREATE INDEX idx_fin_caja_gasto_fecha ON public.fin_caja_gasto USING btree (fecha)
WHERE
  (estado = 1);

CREATE INDEX idx_fin_caja_gasto_sesion ON public.fin_caja_gasto USING btree (id_sesion)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_categoria_gasto_fkey FOREIGN KEY (id_categoria_gasto) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria (id);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_sesion_fkey FOREIGN KEY (id_sesion) REFERENCES public.fin_caja_sesion (id);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.fin_caja_gasto
ADD CONSTRAINT fin_caja_gasto_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
