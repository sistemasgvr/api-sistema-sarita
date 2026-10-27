-- Permisos del módulo documentos-salida
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
        'documentos_salida.emitir',
        'Convertir a guía de remisión y emitir/consultar estado SUNAT',
        TRUE
      ),
      (
        'documentos_salida.eliminar',
        'Anular un documento de salida',
        TRUE
      ),
      (
        'documentos_salida.editar',
        'Generar, editar detalle y registrar retorno de un documento de salida',
        TRUE
      ),
      (
        'documentos_salida.ver',
        'Ver detalle de un documento de salida',
        TRUE
      ),
      (
        'documentos_salida.listar',
        'Listar documentos de salida (órdenes, recargas planta, guías)',
        TRUE
      ),
      (
        'documentos_salida.crear',
        'Crear documentos de salida y agregar/quitar líneas',
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
