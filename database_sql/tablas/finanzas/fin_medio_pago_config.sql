-- Configuración del comportamiento de cada medio de pago (caja, efectivo, crédito)
CREATE TABLE public.fin_medio_pago_config (
  id_medio_pago integer NOT NULL,
  es_efectivo boolean DEFAULT FALSE NOT NULL,
  afecta_caja boolean DEFAULT FALSE NOT NULL,
  requiere_cuenta_bancaria boolean DEFAULT FALSE NOT NULL,
  requiere_numero_operacion boolean DEFAULT FALSE NOT NULL,
  es_credito boolean DEFAULT FALSE NOT NULL,
  orden integer DEFAULT 0 NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  CONSTRAINT fin_medio_pago_config_coherente CHECK (
    (
      NOT (
        (
          es_efectivo
          OR es_credito
        )
        AND requiere_cuenta_bancaria
      )
    )
  )
);

ALTER TABLE ONLY public.fin_medio_pago_config
ADD CONSTRAINT fin_medio_pago_config_pkey PRIMARY KEY (id_medio_pago);

ALTER TABLE ONLY public.fin_medio_pago_config
ADD CONSTRAINT fin_medio_pago_config_id_medio_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones (id);
