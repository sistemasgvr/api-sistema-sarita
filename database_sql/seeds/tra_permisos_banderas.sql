-- Permisos del módulo Trabajadores (Padrón de Personal - RR.HH.)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('trabajador.listar', 'Listar trabajadores'),
        ('trabajador.ver', 'Ver detalle de trabajador'),
        ('trabajador.crear', 'Crear trabajadores'),
        ('trabajador.editar', 'Editar trabajadores'),
        ('trabajador.eliminar', 'Dar de baja a trabajadores')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de trabajadores al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'trabajador.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
