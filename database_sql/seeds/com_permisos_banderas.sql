-- Permisos del módulo Compras

UPDATE auth_permisos
SET nombre = 'compras.eliminar',
    descripcion = COALESCE(NULLIF(TRIM(descripcion), ''), 'Anular comprobantes de compra')
WHERE nombre = 'compras_eliminar'
  AND NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = 'compras.eliminar'
  );

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('compras.listar', 'Listar comprobantes de compra'),
        ('compras.ver', 'Ver detalle de comprobante de compra'),
        ('compras.crear', 'Registrar comprobantes de compra'),
        ('compras.editar', 'Editar comprobantes de compra'),
        ('compras.eliminar', 'Anular comprobantes de compra')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'compras.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
