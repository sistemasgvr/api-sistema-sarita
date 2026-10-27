-- Permisos del módulo activos
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('activo.editar', 'Editar activos', TRUE),
      ('activo.listar', 'Listar activos', TRUE),
      ('activo.crear', 'Crear activos', TRUE),
      ('activo.eliminar', 'Eliminar activos', TRUE),
      ('activo.ver', 'Ver detalle de activos', TRUE)
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
