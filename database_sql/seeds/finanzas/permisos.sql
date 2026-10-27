-- Permisos del módulo finanzas
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (
        'finanzas.cxc.ver',
        'Ver cuentas por cobrar',
        TRUE
      ),
      ('finanzas.cxp.ver', 'Ver cuentas por pagar', TRUE),
      (
        'finanzas.cxc.registrar_pago',
        'Registrar cobranzas (cuentas por cobrar)',
        TRUE
      ),
      (
        'finanzas.cxp.registrar_pago',
        'Registrar pagos (cuentas por pagar)',
        TRUE
      ),
      (
        'finanzas.cxp.crear',
        'Crear cuentas por pagar manuales (externas)',
        TRUE
      ),
      (
        'finanzas.cxc.crear',
        'Crear cuentas por cobrar manuales (externas)',
        TRUE
      ),
      (
        'finanzas.cxc.eliminar',
        'Eliminar cuentas por cobrar',
        TRUE
      ),
      (
        'finanzas.cxp.editar',
        'Editar cuentas por pagar',
        TRUE
      ),
      (
        'finanzas.cxp.eliminar',
        'Eliminar cuentas por pagar',
        TRUE
      ),
      (
        'finanzas.cxc.editar',
        'Editar cuentas por cobrar',
        TRUE
      ),
      (
        'finanzas.exportar',
        'Exportar reportes financieros a Excel',
        TRUE
      ),
      (
        'finanzas.garantias.crear',
        'Registrar garantías de clientes',
        TRUE
      ),
      (
        'finanzas.forzar_duplicado',
        'Registrar pagos aunque el sistema detecte posibles duplicados',
        TRUE
      ),
      (
        'finanzas.garantias.ver',
        'Ver garantías de clientes',
        TRUE
      ),
      (
        'finanzas.garantias.eliminar',
        'Eliminar garantías de clientes',
        TRUE
      ),
      (
        'finanzas.garantias.editar',
        'Editar garantías de clientes',
        TRUE
      ),
      (
        'finanzas.garantias.reembolsar',
        'Registrar reembolso de garantías',
        TRUE
      ),
      ('caja.ver', 'Ver caja y arqueo del día', TRUE),
      (
        'caja.registrar_gasto',
        'Registrar gastos menudos de caja',
        TRUE
      ),
      (
        'caja.registrar_deposito',
        'Registrar depósitos a banco desde caja',
        TRUE
      ),
      (
        'caja.observacion',
        'Registrar observaciones del libro diario',
        TRUE
      ),
      (
        'caja.libro_diario',
        'Ver libro diario operativo',
        TRUE
      ),
      (
        'caja.cerrar',
        'Cerrar / arquear sesión de caja',
        TRUE
      ),
      ('caja.abrir', 'Abrir sesión de caja', TRUE)
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
