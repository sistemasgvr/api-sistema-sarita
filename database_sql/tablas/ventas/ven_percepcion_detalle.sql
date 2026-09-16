CREATE TABLE ven_percepcion_detalle (
    id integer NOT NULL,
    id_percepcion integer NOT NULL,
    id_comprobante integer,
    tipo_doc character varying(5) NOT NULL,
    num_doc character varying(30) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_percepcion date NOT NULL,
    moneda character varying(5) DEFAULT 'PEN' NOT NULL,
    imp_total numeric(12,4) DEFAULT 0 NOT NULL,
    imp_percibido numeric(12,4) DEFAULT 0 NOT NULL,
    imp_cobrar numeric(12,4) DEFAULT 0 NOT NULL,
    tipo_cambio_moneda_ref character varying(5) DEFAULT 'PEN',
    tipo_cambio_moneda_obj character varying(5) DEFAULT 'PEN',
    tipo_cambio_factor numeric(10,6) DEFAULT 1,
    tipo_cambio_fecha date,
    estado integer DEFAULT 1 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_percepcion_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_percepcion_detalle_id_seq OWNED BY public.ven_percepcion_detalle.id;

ALTER TABLE ven_percepcion_detalle ALTER COLUMN id SET DEFAULT nextval('public.ven_percepcion_detalle_id_seq'::regclass);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_pkey PRIMARY KEY (id);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_id_percepcion_fkey FOREIGN KEY (id_percepcion) REFERENCES public.ven_percepcion(id);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);
