-- Permisos del módulo balones
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
        'tipos_balon.listar',
        'Listar tipos de balón',
        TRUE
      ),
      (
        'prestamos_balon.ver',
        'Ver detalle de préstamo',
        TRUE
      ),
      (
        'mantenimientos_balon.listar',
        'Listar mantenimientos de cilindros',
        TRUE
      ),
      (
        'prestamos_detalle.eliminar',
        'Eliminar detalle de préstamo',
        TRUE
      ),
      (
        'mantenimientos_balon.editar',
        'Editar mantenimientos',
        TRUE
      ),
      (
        'alquileres_balon.ver',
        'Ver detalle de alquiler',
        TRUE
      ),
      (
        'alquileres_balon.editar',
        'Editar alquileres de regulador/accesorio',
        TRUE
      ),
      ('balones.ver', 'Ver detalle de balón', TRUE),
      (
        'prestamos_balon.eliminar',
        'Eliminar préstamos de cilindros',
        TRUE
      ),
      (
        'alquileres_balon.listar',
        'Listar alquileres de regulador/accesorio',
        TRUE
      ),
      (
        'movimientos_recarga.crear',
        'Registrar movimientos de recarga',
        TRUE
      ),
      (
        'prestamos_detalle.listar',
        'Listar detalle de préstamos',
        TRUE
      ),
      (
        'movimientos_balon.editar',
        'Editar movimientos de balón',
        TRUE
      ),
      (
        'movimientos_balon.crear',
        'Registrar movimientos de balón',
        TRUE
      ),
      ('balones.crear', 'Registrar balones', TRUE),
      (
        'prestamos_detalle.crear',
        'Agregar cilindros a préstamo',
        TRUE
      ),
      (
        'mantenimientos_balon.crear',
        'Registrar mantenimientos',
        TRUE
      ),
      (
        'movimientos_balon.ver',
        'Ver detalle de movimiento de balón',
        TRUE
      ),
      (
        'mantenimientos_balon.ver',
        'Ver detalle de mantenimiento',
        TRUE
      ),
      (
        'prestamos_detalle.editar',
        'Editar detalle de préstamo',
        TRUE
      ),
      (
        'balones.listar',
        'Listar balones / cilindros',
        TRUE
      ),
      (
        'prestamos_balon.crear',
        'Crear préstamos de cilindros',
        TRUE
      ),
      (
        'prestamos_balon.listar',
        'Listar préstamos de cilindros',
        TRUE
      ),
      ('balones.eliminar', 'Eliminar balones', TRUE),
      (
        'movimientos_balon.eliminar',
        'Anular movimientos de balón',
        TRUE
      ),
      (
        'movimientos_recarga.editar',
        'Editar movimientos de recarga',
        TRUE
      ),
      (
        'alquileres_balon.crear',
        'Crear alquileres de regulador/accesorio',
        TRUE
      ),
      ('tipos_balon.crear', 'Crear tipos de balón', TRUE),
      (
        'movimientos_recarga.eliminar',
        'Anular movimientos de recarga',
        TRUE
      ),
      (
        'movimientos_recarga.listar',
        'Listar movimientos de recarga',
        TRUE
      ),
      (
        'tipos_balon.eliminar',
        'Eliminar tipos de balón',
        TRUE
      ),
      (
        'prestamos_detalle.ver',
        'Ver detalle por cilindro en préstamo',
        TRUE
      ),
      (
        'tipos_balon.ver',
        'Ver detalle de tipo de balón',
        TRUE
      ),
      (
        'alquileres_balon.eliminar',
        'Eliminar alquileres de regulador/accesorio',
        TRUE
      ),
      (
        'prestamos_balon.editar',
        'Editar préstamos de cilindros',
        TRUE
      ),
      (
        'movimientos_balon.listar',
        'Listar movimientos de balón',
        TRUE
      ),
      (
        'mantenimientos_balon.eliminar',
        'Eliminar mantenimientos',
        TRUE
      ),
      ('balones.editar', 'Editar balones', TRUE),
      (
        'tipos_balon.editar',
        'Editar tipos de balón',
        TRUE
      ),
      (
        'movimientos_recarga.ver',
        'Ver detalle de movimiento de recarga',
        TRUE
      ),
      (
        'bajas_balon.ver',
        'Ver detalle de solicitud de baja de cilindro',
        TRUE
      ),
      (
        'bajas_balon.rechazar',
        'Rechazar solicitudes de baja de cilindro',
        TRUE
      ),
      (
        'bajas_balon.aprobar',
        'Aprobar solicitudes de baja de cilindro',
        TRUE
      ),
      (
        'bajas_balon.solicitar',
        'Solicitar baja de cilindro',
        TRUE
      ),
      (
        'bajas_balon.listar',
        'Listar solicitudes de baja de cilindro',
        TRUE
      ),
      (
        'rutas_pueblos.listar',
        'Listar controles de ruta a pueblos',
        TRUE
      ),
      (
        'rutas_pueblos.ver',
        'Ver detalle de ruta a pueblos',
        TRUE
      ),
      (
        'rutas_pueblos.editar',
        'Editar / retornar / cerrar ruta a pueblos',
        TRUE
      ),
      (
        'rutas_pueblos.crear',
        'Crear control de ruta a pueblos',
        TRUE
      ),
      (
        'rutas_pueblos.eliminar',
        'Eliminar control de ruta a pueblos',
        TRUE
      ),
      (
        'lotes_protocolo.listar',
        'Listar fichas de lote y protocolo (ICP)',
        TRUE
      ),
      (
        'lotes_protocolo.ver',
        'Ver detalle de ficha de lote y protocolo',
        TRUE
      ),
      (
        'lotes_protocolo.crear',
        'Registrar fichas de lote y protocolo',
        TRUE
      ),
      (
        'lotes_protocolo.eliminar',
        'Eliminar fichas de lote y protocolo',
        TRUE
      ),
      (
        'lotes_protocolo.editar',
        'Editar fichas de lote y protocolo',
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
