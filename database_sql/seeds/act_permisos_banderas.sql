-- Permisos del módulo Activos (Inventario de activos fijos de la empresa)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('activo.listar', 'Listar activos de la empresa'),
        ('activo.ver', 'Ver detalle de activo'),
        ('activo.crear', 'Crear activos'),
        ('activo.editar', 'Editar activos'),
        ('activo.eliminar', 'Dar de baja a activos')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de activos al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'activo.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
