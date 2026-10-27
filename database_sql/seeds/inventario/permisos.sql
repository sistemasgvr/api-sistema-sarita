-- Permisos del módulo inventario
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
        'inventario_movimientos.ver',
        'Ver detalle de movimientos de inventario',
        TRUE
      ),
      (
        'inventario_movimientos.listar',
        'Listar movimientos de inventario',
        TRUE
      ),
      (
        'inventario_movimientos.crear',
        'Crear movimientos de inventario',
        TRUE
      ),
      (
        'inventario_movimientos.eliminar',
        'Eliminar movimientos de inventario',
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
