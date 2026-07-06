-- Listas maestras y opciones del módulo Balones / Cilindros (ejecutar después de gen_lista base)

-- ============================================================
-- LISTAS (gen_lista)
-- ============================================================

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TipoMovBalon', 'Tipos de movimiento de balón / cilindro'),
        ('EstadoBalon', 'Estados posibles de un balón físico'),
        ('TipoPrestamo', 'Tipos de préstamo de cilindro'),
        ('TipoMantenimiento', 'Tipos de mantenimiento de cilindro'),
        ('ReferenciaCilindro', 'Ubicación o referencia del cilindro'),
        ('EstadoPrestamoDetalle', 'Estado por cilindro en préstamo'),
        ('EstadoCilindroVenta', 'Estado en venta con cilindro'),
        ('PropietarioBalon', 'Propiedad del envase: empresa, cliente o propia'),
        ('EstadoPrestamo', 'Estado del préstamo de cilindros'),
        ('EstadoAlquiler', 'Estado del alquiler de cilindros'),
        ('EstadoMantenimiento', 'Estado del mantenimiento de cilindro')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- ============================================================
-- OPCIONES (gen_lista_opciones)
-- ============================================================

-- TipoMovBalon
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('SALIDA_VENTA', 'Salida por venta de gas'),
        ('SALIDA_PRESTAMO', 'Salida por préstamo a cliente'),
        ('SALIDA_ALQUILER', 'Salida por alquiler'),
        ('SALIDA_MANTENIMIENTO', 'Salida a mantenimiento o taller'),
        ('ENTRADA_DEVOLUCION', 'Entrada por devolución de cliente'),
        ('ENTRADA_LLENADO', 'Entrada desde planta de llenado'),
        ('TRASLADO_LIMA', 'Traslado hacia Lima'),
        ('RETORNO_LIMA', 'Retorno desde Lima')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoBalon
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('EN_ALMACEN', 'Cilindro en almacén'),
        ('POR_RECOGER', 'Pendiente de recoger en cliente'),
        ('PRESTADO_CLIENTE', 'Prestado a cliente'),
        ('EN_RUTA_LIMA', 'En tránsito o en Lima'),
        ('EN_MANTENIMIENTO', 'En mantenimiento o prueba hidrostática'),
        ('ALQUILADO', 'En alquiler activo'),
        ('DEVUELTO', 'Devuelto por cliente'),
        ('ROBO', 'Reportado como robado o extraviado'),
        ('DADO_DE_BAJA', 'Dado de baja definitiva')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoPrestamo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ENVASE_EMPRESA_A_CLIENTE', 'Envase de la empresa prestado al cliente'),
        ('CILINDRO_CLIENTE_A_EMPRESA', 'Cilindro del cliente recibido en empresa'),
        ('CILINDRO_A_PLANTA', 'Cilindro enviado a planta proveedora')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoPrestamo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoMantenimiento
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PRUEBA_HIDROSTATICA', 'Prueba hidrostática'),
        ('RECERTIFICACION', 'Recertificación del cilindro'),
        ('REPARACION', 'Reparación general'),
        ('PINTURA', 'Pintura y rotulado'),
        ('VALVULA', 'Cambio o reparación de válvula')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMantenimiento'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- ReferenciaCilindro
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ALMACEN', 'Referencia en almacén'),
        ('CLIENTE', 'Referencia en cliente'),
        ('CLIENTE_EXTRAVIADA', 'Cliente con cilindro extraviado'),
        ('ALMACEN_EXTRAVIADA', 'Almacén con cilindro extraviado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'ReferenciaCilindro'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoPrestamoDetalle
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVO', 'Cilindro en préstamo activo'),
        ('PENDIENTE', 'Pendiente de entrega'),
        ('DEVUELTO', 'Cilindro devuelto'),
        ('VENCIDO', 'Préstamo vencido sin devolución')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoPrestamoDetalle'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoCilindroVenta
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('POR_RECOGER', 'Cilindro por recoger en venta'),
        ('DEVUELTO', 'Cilindro devuelto en venta')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoCilindroVenta'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- PropietarioBalon
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('EMPRESA', 'Envase propiedad de la empresa'),
        ('CLIENTE', 'Envase propiedad del cliente'),
        ('PROPIA', 'Propiedad propia / particular')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'PropietarioBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoPrestamo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVO', 'Préstamo en curso'),
        ('CERRADO', 'Préstamo cerrado'),
        ('VENCIDO', 'Préstamo vencido')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoPrestamo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoAlquiler
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVO', 'Alquiler en curso'),
        ('FINALIZADO', 'Alquiler finalizado'),
        ('FACTURADO', 'Alquiler facturado al cliente')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoAlquiler'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoMantenimiento
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Mantenimiento pendiente'),
        ('EN_PROCESO', 'Mantenimiento en proceso'),
        ('FINALIZADO', 'Mantenimiento finalizado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoMantenimiento'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
