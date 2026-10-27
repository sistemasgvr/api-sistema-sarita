-- Intentos de envío de guías de remisión al proveedor con solicitud y respuesta
CREATE TABLE public.doc_gre_intento (
  id bigint NOT NULL,
  id_doc_salida integer NOT NULL,
  estado text NOT NULL,
  solicitud jsonb NOT NULL,
  documento jsonb NOT NULL,
  respuesta jsonb,
  id_usuario integer,
  creado timestamp with time zone DEFAULT now() NOT NULL,
  actualizado timestamp with time zone DEFAULT now() NOT NULL,
  id_empresa integer,
  ruc_emisor character varying(11),
  entorno text,
  id_empresa_pse integer,
  consultas integer DEFAULT 0 NOT NULL,
  proxima_consulta timestamp with time zone,
  CONSTRAINT doc_gre_intento_estado_check CHECK (
    (
      estado = ANY (
        ARRAY[
          'ENVIANDO'::text,
          'POR_CONFIRMAR'::text,
          'PENDIENTE'::text,
          'ACEPTADO'::text,
          'RECHAZADO'::text
        ]
      )
    )
  )
);

CREATE SEQUENCE public.doc_gre_intento_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.doc_gre_intento_id_seq OWNED BY public.doc_gre_intento.id;

ALTER TABLE ONLY public.doc_gre_intento
ALTER COLUMN id
SET DEFAULT nextval('public.doc_gre_intento_id_seq'::regclass);

ALTER TABLE ONLY public.doc_gre_intento
ADD CONSTRAINT doc_gre_intento_pkey PRIMARY KEY (id);

CREATE INDEX ix_doc_gre_intento_pendientes ON public.doc_gre_intento USING btree (proxima_consulta)
WHERE
  (
    estado = ANY (ARRAY['PENDIENTE'::text, 'POR_CONFIRMAR'::text])
  );

CREATE UNIQUE INDEX uq_doc_gre_intento_abierto ON public.doc_gre_intento USING btree (id_doc_salida)
WHERE
  (estado <> 'RECHAZADO'::text);

ALTER TABLE ONLY public.doc_gre_intento
ADD CONSTRAINT doc_gre_intento_id_doc_salida_fkey FOREIGN KEY (id_doc_salida) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.doc_gre_intento
ADD CONSTRAINT doc_gre_intento_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);
