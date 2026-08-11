-- Permisos Caja / Libro diario (también en migración 20260811_fin_caja_libro_diario.sql)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('caja.ver', 'Ver caja y arqueo del día'),
        ('caja.abrir', 'Abrir sesión de caja'),
        ('caja.cerrar', 'Cerrar / arquear sesión de caja'),
        ('caja.registrar_gasto', 'Registrar gastos menudos de caja'),
        ('caja.registrar_deposito', 'Registrar depósitos a banco desde caja'),
        ('caja.observacion', 'Registrar observaciones del libro diario'),
        ('caja.libro_diario', 'Ver libro diario operativo')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'caja.%'
  AND NOT EXISTS (
      SELECT 1 FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
