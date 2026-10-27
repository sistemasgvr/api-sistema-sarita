-- PDF generado de un intento de envío de guía de remisión
CREATE TABLE public.doc_gre_archivo (
  id_intento bigint NOT NULL,
  pdf_base64 text NOT NULL,
  creado timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.doc_gre_archivo
ADD CONSTRAINT doc_gre_archivo_pkey PRIMARY KEY (id_intento);

ALTER TABLE ONLY public.doc_gre_archivo
ADD CONSTRAINT doc_gre_archivo_id_intento_fkey FOREIGN KEY (id_intento) REFERENCES public.doc_gre_intento (id);
