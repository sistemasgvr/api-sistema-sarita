-- Balones origen y cantidad usados en una recarga
CREATE TABLE public.bal_movimiento_recarga_origen (
  id integer NOT NULL,
  id_movimiento_recarga integer NOT NULL,
  id_balon integer NOT NULL,
  cantidad numeric(10, 4) NOT NULL,
  orden integer DEFAULT 1 NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  fecha_creacion timestamp without time zone DEFAULT now()
);

COMMENT ON TABLE public.bal_movimiento_recarga_origen IS 'Detalle de balones empresa usados para surtir una recarga cliente (puede ser más de uno).';

CREATE SEQUENCE public.bal_movimiento_recarga_origen_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_movimiento_recarga_origen_id_seq OWNED BY public.bal_movimiento_recarga_origen.id;

ALTER TABLE ONLY public.bal_movimiento_recarga_origen
ALTER COLUMN id
SET DEFAULT nextval(
  'public.bal_movimiento_recarga_origen_id_seq'::regclass
);

ALTER TABLE ONLY public.bal_movimiento_recarga_origen
ADD CONSTRAINT bal_movimiento_recarga_origen_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_mov_recarga_origen_mov ON public.bal_movimiento_recarga_origen USING btree (id_movimiento_recarga);

ALTER TABLE ONLY public.bal_movimiento_recarga_origen
ADD CONSTRAINT bal_movimiento_recarga_origen_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_movimiento_recarga_origen
ADD CONSTRAINT bal_movimiento_recarga_origen_id_movimiento_recarga_fkey FOREIGN KEY (id_movimiento_recarga) REFERENCES public.bal_movimiento_recarga (id);

ALTER TABLE ONLY public.bal_movimiento_recarga_origen
ADD CONSTRAINT bal_movimiento_recarga_origen_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);
