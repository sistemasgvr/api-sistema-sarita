-- Eventos de una sesión de caja con tipo, monto, diferencia y usuario
CREATE TABLE public.fin_caja_sesion_evento (
  id integer NOT NULL,
  id_sesion integer NOT NULL,
  tipo character varying(20) NOT NULL,
  monto numeric(12, 2),
  diferencia numeric(12, 2),
  observacion character varying(500),
  id_usuario integer,
  fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT fin_caja_sesion_evento_tipo_check CHECK (
    (
      (tipo)::text = ANY (
        (
          ARRAY[
            'ABRIR'::character varying,
            'CERRAR'::character varying,
            'REABRIR'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

CREATE SEQUENCE public.fin_caja_sesion_evento_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.fin_caja_sesion_evento_id_seq OWNED BY public.fin_caja_sesion_evento.id;

ALTER TABLE ONLY public.fin_caja_sesion_evento
ALTER COLUMN id
SET DEFAULT nextval('public.fin_caja_sesion_evento_id_seq'::regclass);

ALTER TABLE ONLY public.fin_caja_sesion_evento
ADD CONSTRAINT fin_caja_sesion_evento_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_caja_sesion_evento_sesion_fecha ON public.fin_caja_sesion_evento USING btree (id_sesion, fecha_hora);

ALTER TABLE ONLY public.fin_caja_sesion_evento
ADD CONSTRAINT fin_caja_sesion_evento_id_sesion_fkey FOREIGN KEY (id_sesion) REFERENCES public.fin_caja_sesion (id);
