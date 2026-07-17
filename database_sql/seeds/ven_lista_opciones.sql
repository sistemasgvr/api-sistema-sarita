-- Listas maestras y opciones del módulo Ventas / Facturación (ejecutar después de gen_lista base)

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TipoComprobante', 'Tipos: 01=Factura, 03=Boleta, 07=NC, 08=ND, NV=Nota de venta (interno)'),
        ('MotivoNotaCredito', 'Motivos nota de crédito SUNAT'),
        ('MotivoNotaDebito', 'Motivos nota de débito SUNAT'),
        ('TipoOperacionSunat', 'Catálogo 51 - tipo de operación'),
        ('EstadoSunat', 'Estado del comprobante electrónico ante SUNAT'),
        ('EstadoDocumento', 'Estado interno del comprobante de venta'),
        ('TipoVenta', 'Clasificación de venta en el sistema'),
        ('AfectacionIgv', 'Catálogo 07 - afectación al IGV'),
        ('EstadoCuota', 'Estado de cuota de crédito'),
        ('EstadoGarantia', 'Estados de garantía de envase'),
        ('TipoMovimientoGarantia', 'COBRO y DEVOLUCION de garantía')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- TipoComprobante (código SUNAT en descripcion)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('FACTURA', '01'),
        ('BOLETA', '03'),
        ('NOTA_CREDITO', '07'),
        ('NOTA_DEBITO', '08'),
        ('NOTA_VENTA', 'NV')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoComprobante'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MotivoNotaCredito
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ANULACION_OPERACION', '01'),
        ('ANULACION_ERROR_RUC', '02'),
        ('CORRECCION_ERROR_DESCRIPCION', '03'),
        ('DESCUENTO_GLOBAL', '04'),
        ('DESCUENTO_ITEM', '05'),
        ('DEVOLUCION_TOTAL', '06'),
        ('DEVOLUCION_ITEM', '07'),
        ('BONIFICACION', '08'),
        ('DISMINUCION_VALOR', '09'),
        ('OTROS_CONCEPTOS', '10'),
        ('AJUSTES_AFECTOS_IVAP', '11'),
        ('AJUSTES_OPERACIONES_EXPORTACION', '12'),
        ('AJUSTES_MONTO_Y_O_FECHA_PAGO', '13')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoNotaCredito'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MotivoNotaDebito
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('INTERESES_MORA', '01'),
        ('AUMENTO_VALOR', '02'),
        ('PENALIDADES', '03'),
        ('AJUSTES_OPERACIONES_EXPORTACION', '11')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoNotaDebito'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoOperacionSunat
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('VENTA_INTERNA', '0101'),
        ('VENTA_INTERNA_ANTICIPOS', '0102'),
        ('VENTA_ITINERANTE', '0103'),
        ('VENTA_INTERNA_SUJETA_IVAP', '0104'),
        ('VENTA_EXPORTACION', '0200')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoOperacionSunat'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoSunat
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Sin enviar o en proceso'),
        ('ACEPTADO', 'Aceptado por SUNAT'),
        ('RECHAZADO', 'Rechazado por SUNAT'),
        ('BAJA', 'Dado de baja'),
        ('NO_APLICA', 'Documento interno (no CPE / no SUNAT)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoSunat'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoDocumento (comprobante interno)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Borrador o pendiente de pago'),
        ('PAGADO', 'Cobrado'),
        ('ANULADO', 'Anulado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoDocumento'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoVenta
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('VENTA_GAS', 'Venta de gas'),
        ('VENTA_CON_CILINDRO', 'Venta con cilindro'),
        ('VENTA_CON_GRE', 'Venta con guía de remisión'),
        ('VENTA_SERVICIO', 'Venta de servicio'),
        ('GARANTIA', 'Cobro de garantía')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoVenta'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- AfectacionIgv
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('GRAVADO_OPERACION_ONEROSA', '10'),
        ('EXONERADO_OPERACION_ONEROSA', '20'),
        ('INAFECTO_OPERACION_ONEROSA', '30'),
        ('EXPORTACION', '40')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'AfectacionIgv'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoCuota
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Cuota pendiente'),
        ('PAGADO', 'Cuota pagada'),
        ('VENCIDO', 'Cuota vencida')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoCuota'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- Moneda (si no existe en seeds globales)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PEN', 'Soles'),
        ('USD', 'Dólares americanos')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'Moneda'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MedioPago (si no existe)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('EFECTIVO', 'Pago en efectivo'),
        ('TRANSFERENCIA', 'Transferencia bancaria'),
        ('TARJETA', 'Tarjeta débito/crédito'),
        ('CREDITO', 'Venta a crédito')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MedioPago'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
