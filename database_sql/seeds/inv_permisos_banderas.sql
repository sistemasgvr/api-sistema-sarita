-- Permisos del módulo Inventario - Movimientos unificados (Fase 1, hito 1).
-- Ejecutar después de aplicar database_sql/migraciones/20260901_inv_movimiento_fundamento.sql.

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('inventario_movimientos.listar', 'Listar movimientos de inventario unificados (producto y balón)'),
        ('inventario_movimientos.ver', 'Ver detalle de movimiento unificado'),
        ('inventario_movimientos.crear', 'Registrar movimientos de inventario unificados (ajuste manual)'),
        ('inventario_movimientos.eliminar', 'Anular movimientos de inventario unificados sin documento origen')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar los nuevos permisos al rol Administrador.
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre IN (
      'inventario_movimientos.listar',
      'inventario_movimientos.ver',
      'inventario_movimientos.crear',
      'inventario_movimientos.eliminar'
  )
  AND NOT EXISTS (
      SELECT 1 FROM auth_roles_permisos rp WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
