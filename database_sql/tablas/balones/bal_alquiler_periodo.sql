-- Periodos facturados de un alquiler con fechas, monto y comprobante
CREATE TABLE public.bal_alquiler_periodo (
  id integer NOT NULL,
  id_alquiler integer NOT NULL,
  numero_periodo integer NOT NULL,
  fecha_inicio date NOT NULL,
  fecha_fin date NOT NULL,
  monto numeric(12, 4) DEFAULT 0 NOT NULL,
  id_producto integer,
  id_comprobante integer,
  id_estado integer,
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

COMMENT ON TABLE public.bal_alquiler_periodo IS 'Historial de periodos/cobros del alquiler medicinal (kit = 1, renovaciones = 2+).';

CREATE SEQUENCE public.bal_alquiler_periodo_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_alquiler_periodo_id_seq OWNED BY public.bal_alquiler_periodo.id;

ALTER TABLE ONLY public.bal_alquiler_periodo
ALTER COLUMN id
SET DEFAULT nextval('public.bal_alquiler_periodo_id_seq'::regclass);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_alquiler_numero_periodo_key UNIQUE (id_alquiler, numero_periodo);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_alquiler_periodo_alq ON public.bal_alquiler_periodo USING btree (id_alquiler)
WHERE
  (estado = 1);

CREATE INDEX idx_bal_alquiler_periodo_fin ON public.bal_alquiler_periodo USING btree (fecha_fin)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_alquiler_fkey FOREIGN KEY (id_alquiler) REFERENCES public.bal_alquiler (id);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_alquiler_periodo
ADD CONSTRAINT bal_alquiler_periodo_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
