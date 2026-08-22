-- Permisos del módulo Documentos de Vencimiento (permisos/certificados de la empresa)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('documentos_vencimiento.listar', 'Listar documentos de vencimiento (permisos/certificados)'),
        ('documentos_vencimiento.ver', 'Ver detalle de documento de vencimiento'),
        ('documentos_vencimiento.crear', 'Crear documento de vencimiento'),
        ('documentos_vencimiento.editar', 'Editar / renovar documento de vencimiento'),
        ('documentos_vencimiento.eliminar', 'Eliminar (baja lógica) documento de vencimiento')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'documentos_vencimiento.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
