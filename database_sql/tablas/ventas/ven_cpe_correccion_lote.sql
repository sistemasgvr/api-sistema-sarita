-- Lotes de corrección de comprobantes electrónicos con plan y bloqueo de numeración
CREATE TABLE public.ven_cpe_correccion_lote (
  id uuid NOT NULL,
  motivo text NOT NULL,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  fecha_fiscal date NOT NULL,
  plan jsonb NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
  numeracion_bloqueada boolean DEFAULT FALSE NOT NULL,
  numeracion_bloqueada_en timestamp with time zone,
  motivo_bloqueo text
);

ALTER TABLE ONLY public.ven_cpe_correccion_lote
ADD CONSTRAINT ven_cpe_correccion_lote_pkey PRIMARY KEY (id);
