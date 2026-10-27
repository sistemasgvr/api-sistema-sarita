-- Balones de un préstamo con fechas de entrega, vencimiento y devolución
CREATE TABLE public.bal_prestamo_detalle (
  id integer NOT NULL,
  id_prestamo integer NOT NULL,
  id_balon integer,
  id_producto integer,
  motivo_especifico character varying(255),
  fecha_entregado date,
  fecha_prestamo date,
  dias_prestamo integer DEFAULT 30,
  fecha_vencimiento date,
  fecha_devolucion date,
  serie_guia_entrega character varying(10),
  numero_guia_entrega character varying(15),
  serie_guia_devolucion character varying(10),
  numero_guia_devolucion character varying(15),
  id_estado integer,
  observacion character varying(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_doc_salida_entrega integer,
  id_doc_salida_devolucion integer,
  rol character varying(20) DEFAULT 'ENTREGADO'::character varying NOT NULL,
  CONSTRAINT bal_prestamo_detalle_rol_check CHECK (
    (
      (rol)::text = ANY (
        ARRAY[
          ('ENTREGADO'::character varying)::text,
          ('GARANTIA'::character varying)::text
        ]
      )
    )
  )
);

CREATE SEQUENCE public.bal_prestamo_detalle_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_prestamo_detalle_id_seq OWNED BY public.bal_prestamo_detalle.id;

ALTER TABLE ONLY public.bal_prestamo_detalle
ALTER COLUMN id
SET DEFAULT nextval('public.bal_prestamo_detalle_id_seq'::regclass);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_prestamo_detalle_balon ON public.bal_prestamo_detalle USING btree (id_balon);

CREATE INDEX idx_bal_prestamo_detalle_est ON public.bal_prestamo_detalle USING btree (id_estado);

CREATE INDEX idx_bal_prestamo_detalle_guia_dev ON public.bal_prestamo_detalle USING btree (id_doc_salida_devolucion);

CREATE INDEX idx_bal_prestamo_detalle_guia_ent ON public.bal_prestamo_detalle USING btree (id_doc_salida_entrega);

CREATE INDEX idx_bal_prestamo_detalle_venc ON public.bal_prestamo_detalle USING btree (fecha_vencimiento);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_doc_salida_devolucion_fkey FOREIGN KEY (id_doc_salida_devolucion) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_doc_salida_entrega_fkey FOREIGN KEY (id_doc_salida_entrega) REFERENCES public.doc_salida (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_prestamo_fkey FOREIGN KEY (id_prestamo) REFERENCES public.bal_prestamo (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_prestamo_detalle
ADD CONSTRAINT bal_prestamo_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
