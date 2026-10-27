-- Permisos del módulo dashboard
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
        'dashboard.ver_clientes',
        'Ver dashboard del módulo Clientes',
        TRUE
      ),
      (
        'dashboard.ver_balones',
        'Ver dashboard del módulo Balones',
        TRUE
      ),
      (
        'dashboard.ver_compras',
        'Ver dashboard del módulo Compras',
        TRUE
      ),
      (
        'dashboard.ver_ventas',
        'Ver dashboard del módulo Ventas',
        TRUE
      ),
      (
        'dashboard.ver_garantias',
        'Ver dashboard del módulo Garantías',
        TRUE
      ),
      (
        'dashboard.ver_productos',
        'Ver dashboard del módulo Productos',
        TRUE
      )
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
