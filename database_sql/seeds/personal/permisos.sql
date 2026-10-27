-- Permisos del módulo personal
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
        'trabajador.ver',
        'Ver detalle de trabajadores',
        TRUE
      ),
      ('trabajador.listar', 'Listar trabajadores', TRUE),
      ('trabajador.editar', 'Editar trabajadores', TRUE),
      ('trabajador.crear', 'Crear trabajadores', TRUE),
      (
        'trabajador.eliminar',
        'Eliminar trabajadores',
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
