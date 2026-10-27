-- Permisos del módulo compras
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('compras.listar', 'Permite listar compras', TRUE),
      (
        'compras.ver',
        'Permite ver el detalle de una compra',
        TRUE
      ),
      ('compras.crear', 'Permite crear compras', TRUE),
      ('compras.editar', 'Permite editar compras', TRUE),
      (
        'compras.eliminar',
        'Permite eliminar compras',
        TRUE
      ),
      (
        'retenciones.crear',
        'Crear comprobantes de retención',
        TRUE
      ),
      (
        'retenciones.editar',
        'Editar comprobantes de retención',
        TRUE
      ),
      (
        'retenciones.emitir',
        'Emitir retenciones a SUNAT y descargar PDF/XML oficial',
        TRUE
      ),
      (
        'retenciones.ver',
        'Ver detalle de un comprobante de retención',
        TRUE
      ),
      (
        'retenciones.listar',
        'Listar comprobantes de retención',
        TRUE
      ),
      (
        'retenciones.eliminar',
        'Anular comprobantes de retención',
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
