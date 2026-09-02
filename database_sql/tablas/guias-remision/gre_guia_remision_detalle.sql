-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gre_guia_remision_detalle
-- Generated: 2026-09-02T21:49:18.429Z

CREATE TABLE gre_guia_remision_detalle (
    id integer NOT NULL,
    id_guia_remision integer NOT NULL,
    item integer NOT NULL,
    id_producto integer,
    descripcion character varying(300),
    id_unidad_medida integer,
    cantidad numeric(12,4) NOT NULL,
    id_balon integer,
    glosa character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gre_guia_remision_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gre_guia_remision_detalle_id_seq OWNED BY public.gre_guia_remision_detalle.id;

ALTER TABLE gre_guia_remision_detalle ALTER COLUMN id SET DEFAULT nextval('public.gre_guia_remision_detalle_id_seq'::regclass);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_pkey PRIMARY KEY (id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_balon_fkey FOREIGN KEY (id_balon) REFERENCES public.bal_balon(id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_guia_remision_fkey FOREIGN KEY (id_guia_remision) REFERENCES public.gre_guia_remision(id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_producto_fkey FOREIGN KEY (id_producto) REFERENCES public.pro_producto(id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_guia_remision_detalle
    ADD CONSTRAINT gre_guia_remision_detalle_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
