-- Amplía las opciones de MedioPago con los valores que hoy faltan en la BD.
-- Idempotente: no duplica los ya existentes.

-- Asegurar la lista
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'MedioPago', 'Medios de pago disponibles'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'MedioPago');

-- Opciones (agrega solo las que no existan)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('EFECTIVO',       'Pago en efectivo'),
        ('TRANSFERENCIA',  'Transferencia bancaria'),
        ('DEPOSITO',       'Depósito en cuenta'),
        ('YAPE',           'Pago con Yape'),
        ('PLIN',           'Pago con Plin'),
        ('TARJETA',        'Tarjeta débito/crédito'),
        ('CHEQUE',         'Pago con cheque'),
        ('CREDITO',        'Venta a crédito (sin pago inmediato)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MedioPago'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoCliente: asegurar CLIENTE y PROVEEDOR
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'TipoCliente', 'Rol de la persona/empresa (CLIENTE, PROVEEDOR, EMPLEADO...)'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'TipoCliente');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('CLIENTE',   'Cliente (nos compra)'),
        ('PROVEEDOR', 'Proveedor (le compramos)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoCliente'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
