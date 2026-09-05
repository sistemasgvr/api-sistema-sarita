-- Catálogo TipoMovInvUnificado (Fase 1).
-- El FE fija ListaIds.TIPO_MOV_INV_UNIFICADO = 72 → se inserta con id=72 si no existe.
-- (id 71 quedó para EstadoCicloSalida tras seeds doc_* en DEV limpio desde prod)
-- Idempotente por nombre de lista/opción.

INSERT INTO gen_lista (id, nombre, descripcion, estado)
SELECT 72, 'TipoMovInvUnificado',
       'Tipos de movimiento de inv_movimiento (producto y balon unificados)',
       1
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = 'TipoMovInvUnificado'
);

SELECT setval(
    pg_get_serial_sequence('gen_lista', 'id'),
    GREATEST((SELECT COALESCE(MAX(id), 1) FROM gen_lista), 72)
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('INGRESO', 'Ingreso de producto a almacen'),
        ('SALIDA', 'Salida de producto de almacen'),
        ('TRASLADO', 'Traslado de producto entre almacenes'),
        ('AJUSTE', 'Ajuste manual de stock'),
        ('SALIDA_VENTA', 'Salida de balon por venta'),
        ('SALIDA_PRESTAMO', 'Salida de balon por prestamo'),
        ('SALIDA_ALQUILER', 'Salida de balon por alquiler'),
        ('SALIDA_MANTENIMIENTO', 'Salida de balon a mantenimiento'),
        ('SALIDA_PLANTA_EXTERNA', 'Salida de balon a planta externa'),
        ('ENTRADA_DEVOLUCION', 'Entrada de balon por devolucion'),
        ('ENTRADA_MANTENIMIENTO', 'Entrada de balon desde mantenimiento'),
        ('SALIDA_ENTREGA_CLIENTE', 'Salida de balon por entrega a cliente'),
        ('ENTRADA_LLENADO', 'Entrada de balon lleno'),
        ('ENTRADA_PLANTA_EXTERNA', 'Entrada de balon desde planta externa'),
        ('RECARGA_CLIENTE', 'Recarga de balon en mostrador para cliente'),
        ('TRASLADO_LIMA', 'Traslado de balon en ruta a Lima'),
        ('RETORNO_LIMA', 'Retorno de balon desde Lima'),
        ('REPOSICION', 'Reposicion manual de stock (sin documento)'),
        ('CONSUMO_INTERNO', 'Consumo interno de stock'),
        ('ENTRADA_GARANTIA', 'Entrada de balon por garantia')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovInvUnificado'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
