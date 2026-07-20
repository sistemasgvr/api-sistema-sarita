-- Opciones de lista para cli_baja_cliente

-- MotivoBajaCliente
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'MotivoBajaCliente', 'Motivos de baja de cliente'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'MotivoBajaCliente');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('CIERRE_NEGOCIO', 'Cierre definitivo del negocio'),
        ('TRASLADO_ZONA', 'Cliente se trasladó a otra zona'),
        ('MAL_HISTORIAL', 'Mal historial crediticio o de pagos'),
        ('SOLICITUD_CLIENTE', 'Solicitud expresa del cliente'),
        ('FALLECIMIENTO', 'Fallecimiento del titular'),
        ('OTROS', 'Otro motivo')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoBajaCliente'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoAprobacion
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'EstadoAprobacion', 'Estado de aprobación: PENDIENTE, APROBADA, RECHAZADA'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'EstadoAprobacion');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Solicitud pendiente de revisión'),
        ('APROBADA', 'Solicitud aprobada'),
        ('RECHAZADA', 'Solicitud rechazada')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoAprobacion'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
