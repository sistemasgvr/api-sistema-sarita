-- Listas y opciones del módulo balones
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
        9,
        'ReferenciaCilindro',
        'Ubicación o referencia del cilindro',
        1
      ),
      (
        10,
        'EstadoCilindroVenta',
        'Estado en venta con cilindro',
        1
      ),
      (
        11,
        'EstadoMantenimiento',
        'Estado del mantenimiento de cilindro',
        1
      ),
      (
        12,
        'EstadoAlquiler',
        'Estado del alquiler de regulador/accesorio (el cilindro se presta)',
        1
      ),
      (
        13,
        'EstadoPrestamo',
        'Estado del préstamo de cilindros',
        1
      ),
      (
        14,
        'PropietarioBalon',
        'Propiedad del envase: empresa, cliente o propia',
        1
      ),
      (
        15,
        'EstadoBalon',
        'Estados posibles de un balón físico',
        1
      ),
      (
        16,
        'TipoMantenimiento',
        'Tipos de mantenimiento de cilindro',
        1
      ),
      (
        17,
        'TipoMovBalon',
        'Tipos de movimiento de balón / cilindro',
        1
      ),
      (
        18,
        'TipoPrestamo',
        'Tipos de préstamo de cilindro',
        1
      ),
      (
        19,
        'EstadoPrestamoDetalle',
        'Estado por cilindro en préstamo',
        1
      ),
      (
        20,
        'MotivoBajaBalon',
        'Motivo de baja definitiva del cilindro',
        1
      ),
      (
        21,
        'MarcaCilindro',
        'Marca del fabricante del cilindro',
        1
      ),
      (
        22,
        'OrganoInspectorCilindro',
        'Órgano inspector de la prueba hidrostática',
        1
      ),
      (
        37,
        'TipoRecarga',
        'CLIENTE = cliente trae balón a planta; PLANTA_EXTERNA = envío a tercero',
        1
      ),
      (
        52,
        'EstadoAlquilerPeriodo',
        'PENDIENTE, COBRADO, ANULADO',
        1
      ),
      (
        59,
        'EstadoContenidoBalon',
        'Contenido físico del cilindro: lleno, vacío o desconocido',
        1
      ),
      (
        60,
        'EstadoRecargaPlanta',
        'Estados de la orden de recarga en planta externa',
        1
      ),
      (
        64,
        'CondicionRegulador',
        'Estado físico del regulador/accesorio al recojo',
        1
      ),
      (
        66,
        'EstadoRutaPueblo',
        'Estados del control de ruta a pueblos (libras)',
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
      (
        23,
        'TipoMantenimiento',
        'PRUEBA_HIDROSTATICA',
        'Prueba hidrostática',
        1
      ),
      (
        24,
        'TipoMantenimiento',
        'RECERTIFICACION',
        'Recertificación del cilindro',
        1
      ),
      (
        25,
        'TipoMantenimiento',
        'PINTURA',
        'Pintura y rotulado',
        1
      ),
      (
        26,
        'TipoMantenimiento',
        'REPARACION',
        'Reparación general',
        1
      ),
      (
        27,
        'EstadoPrestamo',
        'ACTIVO',
        'Préstamo en curso',
        1
      ),
      (
        28,
        'EstadoPrestamo',
        'VENCIDO',
        'Préstamo vencido',
        1
      ),
      (
        29,
        'EstadoPrestamo',
        'CERRADO',
        'Préstamo cerrado',
        1
      ),
      (
        30,
        'EstadoMantenimiento',
        'PENDIENTE',
        'Mantenimiento pendiente',
        1
      ),
      (
        31,
        'EstadoMantenimiento',
        'EN_PROCESO',
        'Mantenimiento en proceso',
        1
      ),
      (
        32,
        'EstadoMantenimiento',
        'FINALIZADO',
        'Mantenimiento finalizado',
        1
      ),
      (33, 'MarcaCilindro', 'JD', 'Marca JD', 1),
      (34, 'MarcaCilindro', 'LD', 'Marca LD', 1),
      (
        36,
        'EstadoBalon',
        'DADO_DE_BAJA',
        'Dado de baja',
        1
      ),
      (
        37,
        'EstadoBalon',
        'EN_MANTENIMIENTO',
        'En mantenimiento',
        1
      ),
      (
        45,
        'TipoMovBalon',
        'SALIDA_VENTA',
        'Salida venta',
        1
      ),
      (
        46,
        'TipoMovBalon',
        'RETORNO_LIMA',
        'Retorno Lima',
        1
      ),
      (
        47,
        'TipoMovBalon',
        'SALIDA_MANTENIMIENTO',
        'Salida mantenimiento',
        1
      ),
      (
        48,
        'TipoMovBalon',
        'SALIDA_PRESTAMO',
        'Salida préstamo',
        1
      ),
      (
        49,
        'TipoMovBalon',
        'TRASLADO_LIMA',
        'Traslado Lima',
        1
      ),
      (
        50,
        'TipoMovBalon',
        'ENTRADA_DEVOLUCION',
        'Entrada devolución',
        1
      ),
      (
        51,
        'TipoMovBalon',
        'ENTRADA_LLENADO',
        'Entrada llenado',
        1
      ),
      (
        52,
        'TipoPrestamo',
        'CILINDRO_CLIENTE_A_EMPRESA',
        'Recibido de cliente',
        1
      ),
      (
        53,
        'TipoPrestamo',
        'CILINDRO_A_PLANTA',
        'Enviado a planta',
        1
      ),
      (
        54,
        'TipoPrestamo',
        'ENVASE_EMPRESA_A_CLIENTE',
        'Préstamo a cliente',
        1
      ),
      (55, 'TipoMantenimiento', 'VALVULA', 'Válvula', 1),
      (56, 'MarcaCilindro', 'YA', 'Marca YA', 1),
      (57, 'MarcaCilindro', 'OTRA', 'Otra marca', 1),
      (
        58,
        'MarcaCilindro',
        'ARGENTINA',
        'Marca Argentina',
        1
      ),
      (59, 'MarcaCilindro', 'JP', 'Marca JP', 1),
      (
        60,
        'MarcaCilindro',
        'AMERICANA',
        'Marca Americana',
        1
      ),
      (
        61,
        'MarcaCilindro',
        'BRASILERA',
        'Marca Brasilera',
        1
      ),
      (
        62,
        'OrganoInspectorCilindro',
        'NO_APLICA',
        'Sin órgano inspector',
        1
      ),
      (63, 'OrganoInspectorCilindro', 'OCIA', 'OCIA', 1),
      (
        64,
        'OrganoInspectorCilindro',
        'BUREAU_VERITAS',
        'Bureau Veritas',
        1
      ),
      (65, 'OrganoInspectorCilindro', 'DNV', 'DNV', 1),
      (
        66,
        'OrganoInspectorCilindro',
        'LLOYDS',
        'Lloyd''s Register',
        1
      ),
      (
        67,
        'OrganoInspectorCilindro',
        'OTRO',
        'Otro órgano inspector',
        1
      ),
      (
        184,
        'EstadoAlquilerPeriodo',
        'ANULADO',
        'Periodo anulado',
        1
      ),
      (
        185,
        'EstadoAlquilerPeriodo',
        'PENDIENTE',
        'Periodo generado sin cobro',
        1
      ),
      (
        191,
        'EstadoBalon',
        'EN_PODER_CLIENTE',
        'En cliente',
        1
      ),
      (
        203,
        'EstadoPrestamoDetalle',
        'ACTIVO',
        'Activo',
        1
      ),
      (
        206,
        'EstadoRutaPueblo',
        'CANCELADA',
        'Ruta cancelada',
        1
      ),
      (208, 'EstadoContenidoBalon', 'VACIO', 'Vacío', 1),
      (209, 'EstadoContenidoBalon', 'LLENO', 'Lleno', 1),
      (
        210,
        'EstadoContenidoBalon',
        'DESCONOCIDO',
        'Desconocido',
        1
      ),
      (211, 'EstadoBalon', 'ROBO', 'Robo', 1),
      (
        212,
        'EstadoBalon',
        'PRESTADO_CLIENTE',
        'Prestado',
        1
      ),
      (213, 'EstadoBalon', 'DEVUELTO', 'Devuelto', 1),
      (
        214,
        'EstadoBalon',
        'EN_RUTA_LIMA',
        'En ruta Lima',
        1
      ),
      (
        215,
        'EstadoBalon',
        'POR_RECOGER',
        'Por recoger',
        1
      ),
      (216, 'EstadoBalon', 'ALQUILADO', 'Alquilado', 1),
      (
        217,
        'EstadoBalon',
        'EN_RECARGA_EXTERNA',
        'En recarga',
        1
      ),
      (
        218,
        'ReferenciaCilindro',
        'ALMACEN_EXTRAVIADA',
        'Almacén extraviada',
        1
      ),
      (
        219,
        'ReferenciaCilindro',
        'ALMACEN',
        'Almacén',
        1
      ),
      (
        220,
        'ReferenciaCilindro',
        'CLIENTE',
        'Cliente',
        1
      ),
      (
        221,
        'ReferenciaCilindro',
        'CLIENTE_EXTRAVIADA',
        'Cliente extraviada',
        1
      ),
      (222, 'PropietarioBalon', 'PROPIA', 'Propia', 1),
      (223, 'PropietarioBalon', 'EMPRESA', 'Empresa', 1),
      (224, 'PropietarioBalon', 'CLIENTE', 'Cliente', 1),
      (225, 'PropietarioBalon', 'PLANTA', 'Planta', 1),
      (
        226,
        'EstadoPrestamoDetalle',
        'VENCIDO',
        'Vencido',
        1
      ),
      (
        227,
        'EstadoPrestamoDetalle',
        'DEVUELTO',
        'Devuelto',
        1
      ),
      (
        228,
        'EstadoPrestamoDetalle',
        'PENDIENTE',
        'Pendiente',
        1
      ),
      (
        229,
        'EstadoCilindroVenta',
        'POR_RECOGER',
        'Por recoger',
        1
      ),
      (
        230,
        'EstadoCilindroVenta',
        'DEVUELTO',
        'Devuelto',
        1
      ),
      (
        231,
        'EstadoAlquiler',
        'FACTURADO',
        'Facturado',
        1
      ),
      (232, 'EstadoAlquiler', 'ACTIVO', 'Activo', 1),
      (
        233,
        'EstadoAlquiler',
        'FINALIZADO',
        'Finalizado',
        1
      ),
      (234, 'MotivoBajaBalon', 'PERDIDO', 'Perdido', 1),
      (235, 'MotivoBajaBalon', 'ROBO', 'Robo', 1),
      (236, 'MotivoBajaBalon', 'VENDIDO', 'Vendido', 1),
      (
        237,
        'MotivoBajaBalon',
        'DETERIORO',
        'Deterioro',
        1
      ),
      (238, 'MotivoBajaBalon', 'OTROS', 'Otros', 1),
      (
        240,
        'TipoRecarga',
        'PLANTA_EXTERNA',
        'Planta externa',
        1
      ),
      (241, 'TipoRecarga', 'CLIENTE', 'Mostrador', 1),
      (
        242,
        'TipoMovBalon',
        'RECARGA_CLIENTE',
        'Recarga mostrador',
        1
      ),
      (
        258,
        'TipoMovBalon',
        'ENTRADA_MANTENIMIENTO',
        'Entrada mantenimiento',
        1
      ),
      (
        259,
        'TipoMovBalon',
        'SALIDA_ENTREGA_CLIENTE',
        'Entrega a cliente',
        1
      ),
      (
        260,
        'EstadoAlquilerPeriodo',
        'COBRADO',
        'Cobrado',
        1
      ),
      (
        270,
        'TipoMovBalon',
        'SALIDA_ALQUILER',
        'Salida alquiler',
        1
      ),
      (
        272,
        'EstadoRecargaPlanta',
        'ENVIADO',
        'Enviado',
        1
      ),
      (
        273,
        'EstadoRecargaPlanta',
        'CERRADO',
        'Cerrado',
        1
      ),
      (
        274,
        'EstadoRecargaPlanta',
        'RETORNADO',
        'Retornado',
        1
      ),
      (
        275,
        'EstadoRecargaPlanta',
        'BORRADOR',
        'Borrador',
        1
      ),
      (
        276,
        'CondicionRegulador',
        'PARA_REPARAR',
        'Para reparar',
        1
      ),
      (277, 'CondicionRegulador', 'BUENO', 'Bueno', 1),
      (
        278,
        'TipoMovBalon',
        'ENTRADA_PLANTA_EXTERNA',
        'Retorno de planta',
        1
      ),
      (
        279,
        'TipoMovBalon',
        'SALIDA_PLANTA_EXTERNA',
        'Salida a planta',
        1
      ),
      (282, 'EstadoRutaPueblo', 'CERRADA', 'Cerrada', 1),
      (283, 'EstadoRutaPueblo', 'EN_RUTA', 'En ruta', 1),
      (284, 'EstadoRutaPueblo', 'ABIERTA', 'Abierta', 1),
      (
        299,
        'MarcaCilindro',
        'BTIC-JP',
        'Cilindro BTIC-JP',
        1
      ),
      (
        300,
        'EstadoContenidoBalon',
        'SEMILLLENO',
        'Semi-lleno (gas parcial recibido en recojo de planta)',
        1
      ),
      (
        354,
        'TipoMovBalon',
        'ENTRADA_GARANTIA',
        'Entrada garantía de cliente',
        1
      ),
      (
        355,
        'EstadoBalon',
        'PENDIENTE_ENVIO',
        'En preparación para entrega a cliente',
        1
      ),
      (
        356,
        'EstadoBalon',
        'EN_TRANSITO',
        'Se cambia el estado cuando se inicie la actividad',
        1
      ),
      (
        357,
        'PropietarioBalon',
        'GARANTIA_CLIENTE',
        'Garantía de cliente (préstamo de balón) [Obsoleto 2026-09-06: el propietario es CLIENTE; la garantía se registra en bal_prestamo_detalle.rol = GARANTIA]',
        0
      ),
      (
        358,
        'EstadoBalon',
        'DISPONIBLE',
        'Cuando el cilindro tiene un id almacen de la empresa',
        1
      ),
      (
        359,
        'TipoMovBalon',
        'ENTRADA_COMPRA',
        'Entrada por compra',
        1
      ),
      (396, 'OrganoInspectorCilindro', 'TS', NULL, 1),
      (397, 'MarcaCilindro', 'INDONESIA', NULL, 1),
      (402, 'MarcaCilindro', 'MARCA CHINA', NULL, 1),
      (405, 'MarcaCilindro', 'DOT', NULL, 1),
      (406, 'MarcaCilindro', 'SUIZA', NULL, 1),
      (414, 'MarcaCilindro', 'CATALUX', NULL, 1),
      (420, 'MarcaCilindro', 'SEFIC', NULL, 1),
      (431, 'MarcaCilindro', 'DOVEN', NULL, 1)
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
