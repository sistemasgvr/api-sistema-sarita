-- Sesiones de usuario con token, IP, user agent y fechas de inicio y fin
CREATE TABLE public.auth_sesiones (
  id integer NOT NULL,
  id_usuario integer NOT NULL,
  token character varying(512) NOT NULL,
  ip character varying(45),
  user_agent character varying(512),
  fecha_inicio timestamp without time zone DEFAULT now(),
  fecha_fin timestamp without time zone,
  estado boolean DEFAULT TRUE NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.auth_sesiones_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.auth_sesiones_id_seq OWNED BY public.auth_sesiones.id;

ALTER TABLE ONLY public.auth_sesiones
ALTER COLUMN id
SET DEFAULT nextval('public.auth_sesiones_id_seq'::regclass);

ALTER TABLE ONLY public.auth_sesiones
ADD CONSTRAINT auth_sesiones_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.auth_sesiones
ADD CONSTRAINT auth_sesiones_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.auth_sesiones
ADD CONSTRAINT auth_sesiones_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.auth_sesiones
ADD CONSTRAINT auth_sesiones_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
