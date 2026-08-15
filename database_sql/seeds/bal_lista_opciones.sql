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
        ('EstadoAlquiler', 'Estado del alquiler de regulador/accesorio (el cilindro se presta)'),
        ('EstadoMantenimiento', 'Estado del mantenimiento de cilindro'),
        ('MarcaCilindro', 'Marca del fabricante del cilindro'),
        ('OrganoInspectorCilindro', 'Órgano inspector de la prueba hidrostática'),
        ('MotivoBajaBalon', 'Motivo de baja definitiva del cilindro'),
        ('TipoRecarga', 'CLIENTE = mostrador; PLANTA_EXTERNA = envío a tercero'),
        ('EstadoContenidoBalon', 'Contenido físico del cilindro: lleno, vacío o desconocido'),
        ('EstadoRecargaPlanta', 'Estados de la orden de recarga en planta externa'),
        ('EstadoRecojo', 'Estados de visita de recojo de cilindros en préstamo'),
        ('ResultadoRecojoDetalle', 'Resultado por cilindro en una visita de recojo'),
        ('MotivoFalloRecojo', 'Motivo de fallo / no recogido en visita de recojo'),
        ('EstadoRutaPueblo', 'Estados de control de ruta a pueblos')
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
        ('SALIDA_VENTA', 'Salida venta'),
        ('SALIDA_PRESTAMO', 'Salida préstamo'),
        ('SALIDA_ALQUILER', 'Salida alquiler'),
        ('SALIDA_MANTENIMIENTO', 'Salida mantenimiento'),
        ('SALIDA_PLANTA_EXTERNA', 'Salida a planta'),
        ('ENTRADA_DEVOLUCION', 'Entrada devolución'),
        ('ENTRADA_MANTENIMIENTO', 'Entrada mantenimiento'),
        ('SALIDA_ENTREGA_CLIENTE', 'Entrega a cliente'),
        ('ENTRADA_LLENADO', 'Entrada llenado'),
        ('ENTRADA_PLANTA_EXTERNA', 'Retorno de planta'),
        ('RECARGA_CLIENTE', 'Recarga mostrador'),
        ('TRASLADO_LIMA', 'Traslado Lima'),
        ('RETORNO_LIMA', 'Retorno Lima')
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
        ('EN_ALMACEN', 'En almacén'),
        ('POR_RECOGER', 'Por recoger'),
        ('PRESTADO_CLIENTE', 'Prestado'),
        ('EN_RUTA_LIMA', 'En ruta Lima'),
        ('EN_MANTENIMIENTO', 'En mantenimiento'),
        ('EN_RECARGA_EXTERNA', 'En recarga'),
        ('EN_PODER_CLIENTE', 'En cliente'),
        ('ALQUILADO', 'Alquilado'),
        ('DEVUELTO', 'Devuelto'),
        ('ROBO', 'Robo'),
        ('DADO_DE_BAJA', 'Dado de baja')
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
        ('ENVASE_EMPRESA_A_CLIENTE', 'Préstamo a cliente'),
        ('CILINDRO_CLIENTE_A_EMPRESA', 'Recibido de cliente'),
        ('CILINDRO_A_PLANTA', 'Enviado a planta')
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
        ('VALVULA', 'Válvula')
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
        ('ALMACEN', 'Almacén'),
        ('CLIENTE', 'Cliente'),
        ('CLIENTE_EXTRAVIADA', 'Cliente extraviada'),
        ('ALMACEN_EXTRAVIADA', 'Almacén extraviada')
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
        ('ACTIVO', 'Activo'),
        ('PENDIENTE', 'Pendiente'),
        ('DEVUELTO', 'Devuelto'),
        ('VENCIDO', 'Vencido')
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
        ('POR_RECOGER', 'Por recoger'),
        ('DEVUELTO', 'Devuelto')
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
        ('EMPRESA', 'Empresa'),
        ('CLIENTE', 'Cliente'),
        ('PROPIA', 'Propia'),
        ('PLANTA', 'Planta')
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
        ('ACTIVO', 'Activo'),
        ('FINALIZADO', 'Finalizado'),
        ('FACTURADO', 'Facturado')
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

-- MarcaCilindro
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('JP', 'Marca JP'),
        ('BTIC-JP', 'Cilindro BTIC-JP'),
        ('JD', 'Marca JD'),
        ('YA', 'Marca YA'),
        ('LD', 'Marca LD'),
        ('AMERICANA', 'Marca Americana'),
        ('BRASILERA', 'Marca Brasilera'),
        ('ARGENTINA', 'Marca Argentina'),
        ('OTRA', 'Otra marca')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MarcaCilindro'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- OrganoInspectorCilindro
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('NO_APLICA', 'Sin órgano inspector'),
        ('OCIA', 'OCIA'),
        ('DNV', 'DNV'),
        ('BUREAU_VERITAS', 'Bureau Veritas'),
        ('LLOYDS', 'Lloyd''s Register'),
        ('OTRO', 'Otro órgano inspector')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'OrganoInspectorCilindro'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MotivoBajaBalon
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('VENDIDO', 'Vendido'),
        ('PERDIDO', 'Perdido'),
        ('ROBO', 'Robo'),
        ('DETERIORO', 'Deterioro'),
        ('OTROS', 'Otros')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoBajaBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoRecarga
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('CLIENTE', 'Mostrador'),
        ('PLANTA_EXTERNA', 'Planta externa')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoRecarga'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoContenidoBalon
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('LLENO', 'Lleno'),
        ('VACIO', 'Vacío'),
        ('DESCONOCIDO', 'Desconocido')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoContenidoBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoRecargaPlanta
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('BORRADOR', 'Borrador'),
        ('ENVIADO', 'Enviado'),
        ('RETORNADO', 'Retornado'),
        ('CERRADO', 'Cerrado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoRecargaPlanta'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoRecojo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PROGRAMADO', 'Programado'),
        ('EN_RUTA', 'En ruta'),
        ('EXITOSO', 'Exitoso'),
        ('FALLIDO', 'Fallido'),
        ('REPROGRAMADO', 'Reprogramado'),
        ('CANCELADO', 'Cancelado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoRecojo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- ResultadoRecojoDetalle
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('RECOGIDO', 'Recogido'),
        ('NO_RECOGIDO', 'No recogido'),
        ('EXTENDIDO', 'Fecha extendida')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'ResultadoRecojoDetalle'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MotivoFalloRecojo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('CLIENTE_AUSENTE', 'Cliente ausente'),
        ('SIN_ACCESO', 'Sin acceso'),
        ('CILINDRO_NO_DISPONIBLE', 'No disponible'),
        ('GAS_NO_USADO', 'Gas no usado'),
        ('OTRO', 'Otro')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoFalloRecojo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoRutaPueblo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ABIERTA', 'Ruta abierta (planificada)'),
        ('EN_RUTA', 'Cilindros en tránsito a pueblos'),
        ('CERRADA', 'Ruta cerrada (cuadre de m³)'),
        ('CANCELADA', 'Ruta cancelada')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoRutaPueblo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
