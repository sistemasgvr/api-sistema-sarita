-- Comprobantes de reemplazo emitidos en un lote de corrección
CREATE TABLE public.ven_cpe_correccion_reemplazo (
  id_lote uuid NOT NULL,
  id_comprobante integer NOT NULL,
  serie character varying(4) NOT NULL,
  numero character varying(8) NOT NULL,
  payload jsonb NOT NULL,
  xml_firmado text,
  respuesta jsonb,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  intentos integer DEFAULT 0 NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
ADD CONSTRAINT ven_cpe_correccion_reemplazo_pkey PRIMARY KEY (id_lote, id_comprobante);

ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
ADD CONSTRAINT ven_cpe_correccion_reemplazo_serie_numero_key UNIQUE (serie, numero);

ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
ADD CONSTRAINT ven_cpe_correccion_reemplazo_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);

ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
ADD CONSTRAINT ven_cpe_correccion_reemplazo_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
