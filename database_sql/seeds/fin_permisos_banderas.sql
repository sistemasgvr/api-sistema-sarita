-- Permisos del módulo Finanzas (Cuentas por Cobrar / Pagar y Cobranza)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('finanzas.cxc.ver', 'Ver cuentas por cobrar'),
        ('finanzas.cxc.crear', 'Crear cuentas por cobrar manuales (externas)'),
        ('finanzas.cxc.editar', 'Editar cuentas por cobrar'),
        ('finanzas.cxc.eliminar', 'Eliminar cuentas por cobrar'),
        ('finanzas.cxc.registrar_pago', 'Registrar cobranzas (cuentas por cobrar)'),
        ('finanzas.cxp.ver', 'Ver cuentas por pagar'),
        ('finanzas.cxp.crear', 'Crear cuentas por pagar manuales (externas)'),
        ('finanzas.cxp.editar', 'Editar cuentas por pagar'),
        ('finanzas.cxp.eliminar', 'Eliminar cuentas por pagar'),
        ('finanzas.cxp.registrar_pago', 'Registrar pagos (cuentas por pagar)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de finanzas al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'finanzas.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
