-- Productos de una ruta a pueblo con cantidad de salida y retorno
CREATE TABLE public.bal_ruta_pueblo_detalle_producto (
  id integer NOT NULL,
  id_ruta_pueblo integer NOT NULL,
  id_producto integer NOT NULL,
  cantidad numeric(12, 4) NOT NULL,
  cantidad_retorno numeric(12, 4),
  observacion text,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone,
  estado integer DEFAULT 1,
  CONSTRAINT bal_ruta_pueblo_detalle_producto_cantidad_check CHECK ((cantidad > (0)::numeric))
);

COMMENT ON TABLE public.bal_ruta_pueblo_detalle_producto IS 'Detalle de productos enviados en ruta a pueblos';

COMMENT ON COLUMN public.bal_ruta_pueblo_detalle_producto.cantidad_retorno IS 'Cantidad retornada al almacén (NULL = aún no retornado)';

CREATE SEQUENCE public.bal_ruta_pueblo_detalle_producto_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_ruta_pueblo_detalle_producto_id_seq OWNED BY public.bal_ruta_pueblo_detalle_producto.id;

ALTER TABLE ONLY public.bal_ruta_pueblo_detalle_producto
ALTER COLUMN id
SET DEFAULT nextval(
  'public.bal_ruta_pueblo_detalle_producto_id_seq'::regclass
);

ALTER TABLE ONLY public.bal_ruta_pueblo_detalle_producto
ADD CONSTRAINT bal_ruta_pueblo_detalle_producto_pkey PRIMARY KEY (id);

CREATE INDEX idx_ruta_pueblo_det_producto_producto ON public.bal_ruta_pueblo_detalle_producto USING btree (id_producto);

CREATE INDEX idx_ruta_pueblo_det_producto_ruta ON public.bal_ruta_pueblo_detalle_producto USING btree (id_ruta_pueblo)
WHERE
  (estado = 1);

ALTER TABLE ONLY public.bal_ruta_pueblo_detalle_producto
ADD CONSTRAINT bal_ruta_pueblo_detalle_producto_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_ruta_pueblo_detalle_producto
ADD CONSTRAINT bal_ruta_pueblo_detalle_producto_id_ruta_pueblo_fkey FOREIGN KEY (id_ruta_pueblo) REFERENCES public.bal_ruta_pueblo (id);
