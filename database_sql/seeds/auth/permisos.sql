-- Permisos del módulo auth
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('usuarios.eliminar', 'Eliminar usuarios', TRUE),
      ('sesiones.crear', 'Crear sesiones', TRUE),
      ('permisos.ver', 'Ver detalle de permiso', TRUE),
      ('usuarios.ver', 'Ver detalle de usuario', TRUE),
      ('usuarios.crear', 'Crear usuarios', TRUE),
      ('sesiones.ver', 'Ver detalle de sesión', TRUE),
      (
        'usuarios_roles.listar',
        'Listar asignaciones usuario-rol',
        TRUE
      ),
      ('usuarios.editar', 'Editar usuarios', TRUE),
      (
        'roles_permisos.listar',
        'Listar asignaciones rol-permiso',
        TRUE
      ),
      (
        'usuarios_roles.asignar',
        'Asignar rol a usuario',
        TRUE
      ),
      ('sesiones.cerrar', 'Cerrar sesiones', TRUE),
      ('permisos.editar', 'Editar permisos', TRUE),
      ('permisos.crear', 'Crear permisos', TRUE),
      ('usuarios.listar', 'Listar usuarios', TRUE),
      (
        'roles_permisos.quitar',
        'Quitar permiso de rol',
        TRUE
      ),
      ('roles.editar', 'Editar roles', TRUE),
      ('sesiones.listar', 'Listar sesiones', TRUE),
      ('auth.todo', 'Acceso total al sistema', TRUE),
      ('roles.eliminar', 'Eliminar roles', TRUE),
      (
        'usuarios_roles.quitar',
        'Quitar rol de usuario',
        TRUE
      ),
      ('permisos.listar', 'Listar permisos', TRUE),
      ('roles.crear', 'Crear roles', TRUE),
      ('permisos.eliminar', 'Eliminar permisos', TRUE),
      (
        'roles_permisos.asignar',
        'Asignar permiso a rol',
        TRUE
      ),
      ('roles.ver', 'Ver detalle de rol', TRUE),
      ('roles.listar', 'Listar roles', TRUE),
      ('usuarios.activar', 'Activar usuarios', TRUE),
      (
        'notificaciones.ver',
        'Ver detalle de notificación',
        TRUE
      ),
      (
        'notificaciones.ejecutar_jobs',
        'Ejecutar jobs de detección de notificaciones',
        TRUE
      ),
      (
        'notificaciones.crear',
        'Crear/enviar notificaciones (sistema/admin)',
        TRUE
      ),
      (
        'notificaciones.listar',
        'Listar notificaciones propias',
        TRUE
      ),
      (
        'notificaciones.marcar_leida',
        'Marcar notificaciones como leídas',
        TRUE
      )
  ) AS v (nombre, descripcion, estado)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      auth_permisos p
    WHERE
      p.nombre = v.nombre
  );
