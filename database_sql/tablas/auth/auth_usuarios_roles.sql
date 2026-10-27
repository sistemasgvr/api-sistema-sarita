-- Asignación de roles a usuarios
CREATE TABLE public.auth_usuarios_roles (
  id integer NOT NULL,
  id_usuario integer NOT NULL,
  id_rol integer NOT NULL,
  estado boolean DEFAULT TRUE NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE public.auth_usuarios_roles_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.auth_usuarios_roles_id_seq OWNED BY public.auth_usuarios_roles.id;

ALTER TABLE ONLY public.auth_usuarios_roles
ALTER COLUMN id
SET DEFAULT nextval('public.auth_usuarios_roles_id_seq'::regclass);

ALTER TABLE ONLY public.auth_usuarios_roles
ADD CONSTRAINT auth_usuarios_roles_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.auth_usuarios_roles
ADD CONSTRAINT auth_usuarios_roles_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.auth_roles (id);

ALTER TABLE ONLY public.auth_usuarios_roles
ADD CONSTRAINT auth_usuarios_roles_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.auth_usuarios_roles
ADD CONSTRAINT auth_usuarios_roles_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.auth_usuarios_roles
ADD CONSTRAINT auth_usuarios_roles_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
