-- Tokens de control con vencimiento para operaciones CPE por empresa
CREATE TABLE public.ven_cpe_operacion_control (
  id_empresa integer NOT NULL,
  token uuid NOT NULL,
  vencimiento timestamp with time zone NOT NULL
);

ALTER TABLE ONLY public.ven_cpe_operacion_control
ADD CONSTRAINT ven_cpe_operacion_control_pkey PRIMARY KEY (id_empresa);

ALTER TABLE ONLY public.ven_cpe_operacion_control
ADD CONSTRAINT ven_cpe_operacion_control_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);
