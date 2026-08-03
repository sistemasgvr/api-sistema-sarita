-- Permisos del módulo Dashboard (permiso de lectura por cada tab/módulo)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('dashboard.ver_clientes', 'Ver dashboard del módulo Clientes'),
        ('dashboard.ver_balones', 'Ver dashboard del módulo Balones')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de dashboard al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'dashboard.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
