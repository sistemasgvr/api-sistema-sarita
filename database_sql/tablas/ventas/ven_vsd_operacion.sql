-- Operaciones de corrección sobre ventas sin documento (VSD) con datos antes y después
CREATE TABLE public.ven_vsd_operacion (
  id bigint NOT NULL,
  id_comprobante integer NOT NULL,
  tipo character varying(20) NOT NULL,
  solicitud uuid,
  motivo character varying(500) NOT NULL,
  datos jsonb NOT NULL,
  anterior jsonb NOT NULL,
  posterior jsonb NOT NULL,
  id_usuario integer NOT NULL,
  fecha timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_vsd_operacion_motivo_check CHECK ((length(btrim((motivo)::text)) >= 5)),
  CONSTRAINT ven_vsd_operacion_tipo_check CHECK (
    (
      (tipo)::text = ANY (
        (
          ARRAY[
            'CORRECCION'::character varying,
            'CAMBIO_BALON'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

ALTER TABLE public.ven_vsd_operacion
ALTER COLUMN id
ADD GENERATED ALWAYS AS IDENTITY (
  SEQUENCE NAME public.ven_vsd_operacion_id_seq START
  WITH
    1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1
);

ALTER TABLE ONLY public.ven_vsd_operacion
ADD CONSTRAINT ven_vsd_operacion_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.ven_vsd_operacion
ADD CONSTRAINT ven_vsd_operacion_solicitud_key UNIQUE (solicitud);

CREATE INDEX idx_vsd_operacion_venta ON public.ven_vsd_operacion USING btree (id_comprobante, id);

ALTER TABLE ONLY public.ven_vsd_operacion
ADD CONSTRAINT ven_vsd_operacion_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.ven_vsd_operacion
ADD CONSTRAINT ven_vsd_operacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios (id);
