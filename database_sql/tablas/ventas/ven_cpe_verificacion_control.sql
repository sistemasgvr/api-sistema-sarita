-- Tokens de control con vencimiento para verificaciones CPE
CREATE TABLE public.ven_cpe_verificacion_control (
  id smallint NOT NULL,
  token uuid NOT NULL,
  vencimiento timestamp with time zone NOT NULL,
  CONSTRAINT ven_cpe_verificacion_control_id_check CHECK ((id = 1))
);

ALTER TABLE ONLY public.ven_cpe_verificacion_control
ADD CONSTRAINT ven_cpe_verificacion_control_pkey PRIMARY KEY (id);
