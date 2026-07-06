-- Datos iniciales de autenticación (ejecutar después de crear tablas auth)
--
-- Usuario administrador por defecto:
--   Correo:     admin@oxigenosarita.com
--   Contraseña: Admin123!

-- ============================================================
-- Permisos (banderas)
-- ============================================================

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('auth.todo', 'Acceso total al sistema'),
        ('usuarios.listar', 'Listar usuarios'),
        ('usuarios.ver', 'Ver detalle de usuario'),
        ('usuarios.crear', 'Crear usuarios'),
        ('usuarios.editar', 'Editar usuarios'),
        ('usuarios.eliminar', 'Desactivar usuarios'),
        ('usuarios.activar', 'Activar usuarios'),
        ('roles.listar', 'Listar roles'),
        ('roles.ver', 'Ver detalle de rol'),
        ('roles.crear', 'Crear roles'),
        ('roles.editar', 'Editar roles'),
        ('roles.eliminar', 'Eliminar roles'),
        ('permisos.listar', 'Listar permisos'),
        ('permisos.ver', 'Ver detalle de permiso'),
        ('permisos.crear', 'Crear permisos'),
        ('permisos.editar', 'Editar permisos'),
        ('permisos.eliminar', 'Eliminar permisos'),
        ('usuarios_roles.listar', 'Listar asignaciones usuario-rol'),
        ('usuarios_roles.asignar', 'Asignar rol a usuario'),
        ('usuarios_roles.quitar', 'Quitar rol de usuario'),
        ('roles_permisos.listar', 'Listar asignaciones rol-permiso'),
        ('roles_permisos.asignar', 'Asignar permiso a rol'),
        ('roles_permisos.quitar', 'Quitar permiso de rol'),
        ('sesiones.listar', 'Listar sesiones'),
        ('sesiones.ver', 'Ver detalle de sesión'),
        ('sesiones.crear', 'Crear sesiones'),
        ('sesiones.cerrar', 'Cerrar sesiones')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- ============================================================
-- Rol Administrador con todos los permisos
-- ============================================================

INSERT INTO auth_roles (nombre, descripcion)
SELECT 'Administrador', 'Acceso total al sistema'
WHERE NOT EXISTS (
    SELECT 1 FROM auth_roles WHERE nombre = 'Administrador'
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- ============================================================
-- Usuario administrador
-- ============================================================

INSERT INTO auth_usuarios (nombre, correo, contrasena)
SELECT
    'Administrador',
    'admin@oxigenosarita.com',
    '$2b$10$/7utpLm1JxstG8rZuDLc8.JwU5apP5BIyz3J1mSWh8n4GzP1lIDZm'
WHERE NOT EXISTS (
    SELECT 1 FROM auth_usuarios WHERE LOWER(correo) = 'admin@oxigenosarita.com'
);

INSERT INTO auth_usuarios_roles (id_usuario, id_rol)
SELECT u.id, r.id
FROM auth_usuarios u
CROSS JOIN auth_roles r
WHERE LOWER(u.correo) = 'admin@oxigenosarita.com'
  AND r.nombre = 'Administrador'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_usuarios_roles ur
      WHERE ur.id_usuario = u.id AND ur.id_rol = r.id
  );
