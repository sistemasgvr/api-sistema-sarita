-- Tipos de balón con gas, capacidad, peso, presión y vigencia de PH
CREATE TABLE public.bal_tipo_balon (
  id integer NOT NULL,
  nombre character varying(150) NOT NULL,
  id_gas integer,
  capacidad numeric(10, 4),
  id_unidad_medida integer,
  peso numeric(10, 4),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  vigencia_ph_anios integer DEFAULT 5 NOT NULL,
  capacidad_lb numeric(12, 4),
  presion_llenado_psi numeric(12, 2),
  peso_tara_lb numeric(12, 4)
);

COMMENT ON COLUMN public.bal_tipo_balon.capacidad IS 'Capacidad nominal del cilindro en m³ (unidad principal de negocio).';

COMMENT ON COLUMN public.bal_tipo_balon.vigencia_ph_anios IS 'Vigencia de prueba hidrostática en años según tipo/gas (5 medicinal/CO2/mezcla/acetileno, 10 industrial/nitrógeno/argón)';

COMMENT ON COLUMN public.bal_tipo_balon.capacidad_lb IS 'Peso del gas cuando el cilindro está lleno (lb). Factor ruta = capacidad / capacidad_lb.';

COMMENT ON COLUMN public.bal_tipo_balon.presion_llenado_psi IS 'PSI de llenado a capacidad nominal. m³ ≈ capacidad * (PSI_actual / PSI_llenado).';

COMMENT ON COLUMN public.bal_tipo_balon.peso_tara_lb IS 'Peso tara del cilindro vacío en lb. Si null, se deriva de peso (kg) * 2.20462.';

CREATE SEQUENCE public.bal_tipo_balon_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.bal_tipo_balon_id_seq OWNED BY public.bal_tipo_balon.id;

ALTER TABLE ONLY public.bal_tipo_balon
ALTER COLUMN id
SET DEFAULT nextval('public.bal_tipo_balon_id_seq'::regclass);

ALTER TABLE ONLY public.bal_tipo_balon
ADD CONSTRAINT bal_tipo_balon_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.bal_tipo_balon
ADD CONSTRAINT bal_tipo_balon_id_gas_fkey FOREIGN KEY (id_gas) REFERENCES public.pro_producto (id);

ALTER TABLE ONLY public.bal_tipo_balon
ADD CONSTRAINT bal_tipo_balon_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.bal_tipo_balon
ADD CONSTRAINT bal_tipo_balon_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.bal_tipo_balon
ADD CONSTRAINT bal_tipo_balon_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
