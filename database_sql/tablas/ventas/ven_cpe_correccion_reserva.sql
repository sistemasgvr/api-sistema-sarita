-- Series y números reservados para un lote de corrección
CREATE TABLE public.ven_cpe_correccion_reserva (
  serie character varying(4) NOT NULL,
  numero integer NOT NULL,
  id_lote uuid NOT NULL,
  id_comprobante integer NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_cpe_correccion_reserva_numero_check CHECK ((numero > 0)),
  CONSTRAINT ven_cpe_correccion_reserva_serie_check CHECK (
    (
      (serie)::text = ANY (
        (
          ARRAY[
            'F002'::character varying,
            'B002'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

ALTER TABLE ONLY public.ven_cpe_correccion_reserva
ADD CONSTRAINT ven_cpe_correccion_reserva_id_lote_id_comprobante_key UNIQUE (id_lote, id_comprobante);

ALTER TABLE ONLY public.ven_cpe_correccion_reserva
ADD CONSTRAINT ven_cpe_correccion_reserva_pkey PRIMARY KEY (serie, numero);

ALTER TABLE ONLY public.ven_cpe_correccion_reserva
ADD CONSTRAINT ven_cpe_correccion_reserva_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.ven_cpe_correccion_reserva
ADD CONSTRAINT ven_cpe_correccion_reserva_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
