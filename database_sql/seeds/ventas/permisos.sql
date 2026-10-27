-- Permisos del módulo ventas
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
        'comprobantes.ver',
        'Ver detalle de comprobante',
        TRUE
      ),
      (
        'ventas.ver',
        'Acceso al módulo de ventas y facturación',
        TRUE
      ),
      (
        'comprobantes.listar',
        'Listar comprobantes de venta',
        TRUE
      ),
      (
        'comprobantes.crear',
        'Crear comprobantes de venta',
        TRUE
      ),
      (
        'comprobantes.consultar_cdr',
        'Consultar CDR / estado SUNAT',
        TRUE
      ),
      (
        'comprobantes.emitir',
        'Emitir comprobante electrónico ante SUNAT',
        TRUE
      ),
      (
        'comprobantes.eliminar',
        'Anular comprobantes pendientes',
        TRUE
      ),
      (
        'comprobantes.editar',
        'Editar comprobantes pendientes',
        TRUE
      ),
      (
        'guias_remision.listar',
        'Listar guías de remisión',
        TRUE
      ),
      (
        'guias_remision.crear',
        'Crear guías de remisión',
        TRUE
      ),
      (
        'guias_remision.editar',
        'Editar guías de remisión',
        TRUE
      ),
      (
        'guias_remision.emitir',
        'Emitir / consultar estado SUNAT de GRE',
        TRUE
      ),
      (
        'guias_remision.ver',
        'Ver detalle de guía de remisión',
        TRUE
      ),
      (
        'guias_remision.eliminar',
        'Eliminar guías de remisión',
        TRUE
      ),
      (
        'percepciones.crear',
        'Crear comprobantes de percepción',
        TRUE
      ),
      (
        'percepciones.listar',
        'Listar comprobantes de percepción',
        TRUE
      ),
      (
        'percepciones.eliminar',
        'Anular comprobantes de percepción',
        TRUE
      ),
      (
        'percepciones.ver',
        'Ver detalle de un comprobante de percepción',
        TRUE
      ),
      (
        'percepciones.editar',
        'Editar comprobantes de percepción',
        TRUE
      ),
      (
        'percepciones.emitir',
        'Emitir percepciones a SUNAT y descargar PDF/XML oficial',
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
