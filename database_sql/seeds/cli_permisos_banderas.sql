-- Permisos del módulo Clientes (ejecutar después de crear tablas cli_*)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('clientes.listar', 'Listar clientes'),
        ('clientes.ver', 'Ver detalle de cliente'),
        ('clientes.crear', 'Crear clientes'),
        ('clientes.editar', 'Editar clientes'),
        ('clientes.eliminar', 'Eliminar clientes'),
        ('clientes.restaurar', 'Restaurar clientes inactivos')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de clientes al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'clientes.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
