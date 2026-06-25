-- Banderas de permiso iniciales (ejecutar después de crear tablas auth)
-- Asignar auth.todo al rol Administrador para acceso total.

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('auth.todo', 'Acceso total al sistema'),
        ('usuarios.listar', 'Listar usuarios'),
        ('usuarios.ver', 'Ver detalle de usuario'),
        ('usuarios.crear', 'Crear usuarios'),
        ('usuarios.editar', 'Editar usuarios'),
        ('usuarios.eliminar', 'Eliminar usuarios'),
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

-- Ejemplo: rol Administrador con bandera auth.todo
-- INSERT INTO auth_roles (nombre, descripcion)
-- SELECT 'Administrador', 'Acceso total'
-- WHERE NOT EXISTS (SELECT 1 FROM auth_roles WHERE nombre = 'Administrador');
--
-- INSERT INTO auth_roles_permisos (id_rol, id_permiso)
-- SELECT r.id, p.id
-- FROM auth_roles r
-- CROSS JOIN auth_permisos p
-- WHERE r.nombre = 'Administrador' AND p.nombre = 'auth.todo'
--   AND NOT EXISTS (
--       SELECT 1 FROM auth_roles_permisos rp
--       WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
--   );
