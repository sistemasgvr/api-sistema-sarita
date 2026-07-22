INSERT INTO gen_lista (nombre, descripcion)
SELECT 'TipoSolicitud', 'Tipo de solicitud de cliente: BAJA o REACTIVACION'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'TipoSolicitud');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('BAJA', 'Solicitud de baja de cliente'),
        ('REACTIVACION', 'Solicitud de reactivación de cliente')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoSolicitud'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
