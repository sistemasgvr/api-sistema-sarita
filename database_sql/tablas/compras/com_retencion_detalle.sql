-- Tabla: com_retencion_detalle
-- Detalle de documentos asociados a una retención

CREATE TABLE com_retencion_detalle (
    id integer NOT NULL,
    id_retencion integer NOT NULL,
    id_compra integer,
    tipo_doc character varying(5) NOT NULL,
    num_doc character varying(30) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_retencion date NOT NULL,
    moneda character varying(5) DEFAULT 'PEN' NOT NULL,
    imp_total numeric(12,4) DEFAULT 0 NOT NULL,
    imp_retenido numeric(12,4) DEFAULT 0 NOT NULL,
    imp_pagar numeric(12,4) DEFAULT 0 NOT NULL,
    tipo_cambio_moneda_ref character varying(5) DEFAULT 'PEN',
    tipo_cambio_moneda_obj character varying(5) DEFAULT 'PEN',
    tipo_cambio_factor numeric(10,6) DEFAULT 1,
    tipo_cambio_fecha date,
    estado integer DEFAULT 1 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE com_retencion_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE com_retencion_detalle_id_seq OWNED BY public.com_retencion_detalle.id;

ALTER TABLE com_retencion_detalle ALTER COLUMN id SET DEFAULT nextval('public.com_retencion_detalle_id_seq'::regclass);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_pkey PRIMARY KEY (id);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_id_retencion_fkey FOREIGN KEY (id_retencion) REFERENCES public.com_retencion(id);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.com_comprobante_compra(id);
