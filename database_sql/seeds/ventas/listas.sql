-- Listas y opciones del módulo ventas
INSERT INTO
  gen_lista (id, nombre, descripcion, estado)
SELECT
  v.id,
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (
        23,
        'AfectacionIgv',
        'Catálogo 07 - afectación al IGV',
        1
      ),
      (
        25,
        'TipoOperacionSunat',
        'Catálogo 51 - tipo de operación',
        1
      ),
      (
        26,
        'MotivoNotaDebito',
        'Motivos nota de débito SUNAT',
        1
      ),
      (
        27,
        'EstadoSunat',
        'Estado del comprobante electrónico ante SUNAT',
        1
      ),
      (
        28,
        'EstadoDocumento',
        'Estado interno del comprobante de venta',
        1
      ),
      (
        29,
        'TipoMovimientoGarantia',
        'COBRO y DEVOLUCION de garantía',
        1
      ),
      (
        30,
        'EstadoCuota',
        'Estado de cuota de crédito',
        1
      ),
      (
        31,
        'MotivoNotaCredito',
        'Motivos nota de crédito SUNAT',
        1
      ),
      (
        32,
        'TipoVenta',
        'Clasificación de venta en el sistema',
        1
      ),
      (
        33,
        'TipoComprobante',
        'Catálogo SUNAT 01: ventas 01/03/07/08/VSD; compras también 02, 04, 05, 12, 13, 14, 15, 00',
        1
      ),
      (56, 'Moneda', 'Monedas', 1),
      (
        76,
        'RegimenPercepcion',
        'Catálogo 22 SUNAT — régimen de percepción (código en descripcion)',
        1
      ),
      (
        82,
        'TasaPercepcion',
        'Tasas de percepción por régimen (código del régimen en descripcion)',
        1
      )
  ) AS v (id, nombre, descripcion, estado)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      gen_lista l
    WHERE
      l.nombre = v.nombre
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO
  gen_lista_opciones (id, id_lista, nombre, descripcion, estado)
SELECT
  v.id,
  l.id,
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (68, 'TipoComprobante', 'NOTA_DEBITO', '08', 1),
      (69, 'TipoComprobante', 'BOLETA', '03', 1),
      (70, 'TipoComprobante', 'NOTA_CREDITO', '07', 1),
      (71, 'TipoComprobante', 'FACTURA', '01', 1),
      (
        72,
        'MotivoNotaCredito',
        'OTROS_CONCEPTOS',
        '10',
        1
      ),
      (
        73,
        'MotivoNotaCredito',
        'AJUSTES_AFECTOS_IVAP',
        '11',
        1
      ),
      (
        74,
        'MotivoNotaCredito',
        'DEVOLUCION_TOTAL',
        '06',
        1
      ),
      (75, 'MotivoNotaCredito', 'BONIFICACION', '08', 1),
      (
        76,
        'MotivoNotaCredito',
        'DESCUENTO_GLOBAL',
        '04',
        1
      ),
      (
        77,
        'MotivoNotaCredito',
        'AJUSTES_OPERACIONES_EXPORTACION',
        '12',
        1
      ),
      (
        78,
        'MotivoNotaCredito',
        'DISMINUCION_VALOR',
        '09',
        1
      ),
      (
        79,
        'MotivoNotaCredito',
        'CORRECCION_ERROR_DESCRIPCION',
        '03',
        1
      ),
      (
        80,
        'MotivoNotaCredito',
        'DESCUENTO_ITEM',
        '05',
        1
      ),
      (
        81,
        'MotivoNotaCredito',
        'ANULACION_OPERACION',
        '01',
        1
      ),
      (
        82,
        'MotivoNotaCredito',
        'DEVOLUCION_ITEM',
        '07',
        1
      ),
      (
        83,
        'MotivoNotaCredito',
        'ANULACION_ERROR_RUC',
        '02',
        1
      ),
      (
        84,
        'MotivoNotaCredito',
        'AJUSTES_MONTO_Y_O_FECHA_PAGO',
        '13',
        1
      ),
      (
        85,
        'MotivoNotaDebito',
        'AJUSTES_OPERACIONES_EXPORTACION',
        '11',
        1
      ),
      (86, 'MotivoNotaDebito', 'AUMENTO_VALOR', '02', 1),
      (87, 'MotivoNotaDebito', 'PENALIDADES', '03', 1),
      (88, 'MotivoNotaDebito', 'INTERESES_MORA', '01', 1),
      (
        89,
        'TipoOperacionSunat',
        'VENTA_ITINERANTE',
        '0103',
        1
      ),
      (
        90,
        'TipoOperacionSunat',
        'VENTA_INTERNA_ANTICIPOS',
        '0102',
        1
      ),
      (
        91,
        'TipoOperacionSunat',
        'VENTA_INTERNA',
        '0101',
        1
      ),
      (
        92,
        'TipoOperacionSunat',
        'VENTA_INTERNA_SUJETA_IVAP',
        '0104',
        1
      ),
      (
        93,
        'TipoOperacionSunat',
        'VENTA_EXPORTACION',
        '0200',
        1
      ),
      (
        94,
        'EstadoSunat',
        'ACEPTADO',
        'Aceptado por SUNAT',
        1
      ),
      (
        95,
        'EstadoSunat',
        'PENDIENTE',
        'Sin enviar o en proceso',
        1
      ),
      (
        96,
        'EstadoSunat',
        'RECHAZADO',
        'Rechazado por SUNAT',
        1
      ),
      (97, 'EstadoSunat', 'BAJA', 'Dado de baja', 1),
      (98, 'EstadoDocumento', 'PAGADO', 'Cobrado', 1),
      (99, 'EstadoDocumento', 'ANULADO', 'Anulado', 1),
      (
        100,
        'EstadoDocumento',
        'PENDIENTE',
        'Borrador o pendiente de pago',
        1
      ),
      (
        101,
        'TipoVenta',
        'VENTA_CON_CILINDRO',
        'Venta con cilindro',
        1
      ),
      (102, 'TipoVenta', 'VENTA_GAS', 'Venta de gas', 1),
      (
        103,
        'TipoVenta',
        'VENTA_SERVICIO',
        'Venta de servicio',
        1
      ),
      (
        104,
        'TipoVenta',
        'GARANTIA',
        'Cobro de garantía',
        1
      ),
      (
        105,
        'TipoVenta',
        'VENTA_CON_GRE',
        'Venta con guía de remisión',
        1
      ),
      (
        106,
        'AfectacionIgv',
        'INAFECTO_OPERACION_ONEROSA',
        '30',
        1
      ),
      (
        107,
        'AfectacionIgv',
        'EXONERADO_OPERACION_ONEROSA',
        '20',
        1
      ),
      (
        108,
        'AfectacionIgv',
        'GRAVADO_OPERACION_ONEROSA',
        '10',
        1
      ),
      (109, 'AfectacionIgv', 'EXPORTACION', '40', 1),
      (110, 'EstadoCuota', 'PAGADO', 'Cuota pagada', 1),
      (111, 'EstadoCuota', 'VENCIDO', 'Cuota vencida', 1),
      (
        112,
        'EstadoCuota',
        'PENDIENTE',
        'Cuota pendiente',
        1
      ),
      (183, 'TipoComprobante', 'NOTA_VENTA', 'VSD', 1),
      (
        196,
        'Moneda',
        'USD',
        'Dolares Estadounidenses',
        1
      ),
      (207, 'Moneda', 'NUEVOS_SOLES', 'Sol Peruano', 1),
      (247, 'EstadoSunat', 'NO_APLICA', 'No aplica', 1),
      (
        264,
        'TipoMovimientoGarantia',
        'COBRO',
        'Cobro',
        1
      ),
      (
        265,
        'TipoMovimientoGarantia',
        'DEVOLUCION',
        'Devolución',
        1
      ),
      (
        291,
        'TipoComprobante',
        'RECIBO_HONORARIOS',
        '02',
        1
      ),
      (
        292,
        'TipoComprobante',
        'LIQUIDACION_COMPRA',
        '04',
        1
      ),
      (293, 'TipoComprobante', 'BOLETO_AEREO', '05', 1),
      (294, 'TipoComprobante', 'TICKET_MAQUINA', '12', 1),
      (
        295,
        'TipoComprobante',
        'DOCUMENTO_BANCARIO',
        '13',
        1
      ),
      (
        296,
        'TipoComprobante',
        'RECIBO_SERVICIOS_PUBLICOS',
        '14',
        1
      ),
      (
        297,
        'TipoComprobante',
        'BOLETO_TERRESTRE',
        '15',
        1
      ),
      (
        298,
        'TipoComprobante',
        'OTROS_SIN_DOCUMENTO',
        '00',
        1
      ),
      (
        373,
        'TipoMovimientoGarantia',
        'TRANSFERENCIA',
        'Traspaso del saldo entre garantías por renovación (no mueve caja)',
        1
      ),
      (
        384,
        'RegimenPercepcion',
        'Percepción venta interna',
        '01',
        1
      ),
      (
        385,
        'RegimenPercepcion',
        'Percepción a la adquisición de combustible',
        '02',
        1
      ),
      (
        386,
        'RegimenPercepcion',
        'Percepción realizada al agente de percepción con tasa especial',
        '03',
        1
      ),
      (389, 'TasaPercepcion', '1%', '02', 1),
      (390, 'TasaPercepcion', '2%', '01', 1),
      (391, 'TasaPercepcion', '0.5%', '03', 1)
  ) AS v (id, lista, nombre, descripcion, estado)
  JOIN gen_lista l ON l.nombre = v.lista
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      gen_lista_opciones o
    WHERE
      o.id_lista = l.id
      AND o.nombre = v.nombre
  )
ON CONFLICT (id) DO NOTHING;

SELECT
  setval(
    pg_get_serial_sequence('gen_lista', 'id'),
    (
      SELECT
        COALESCE(MAX(id), 0) + 1
      FROM
        gen_lista
    ),
    FALSE
  );

SELECT
  setval(
    pg_get_serial_sequence('gen_lista_opciones', 'id'),
    (
      SELECT
        COALESCE(MAX(id), 0) + 1
      FROM
        gen_lista_opciones
    ),
    FALSE
  );
