-- Permisos del módulo clientes
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('clientes.ver', 'Ver detalle de cliente', TRUE),
      ('clientes.editar', 'Editar clientes', TRUE),
      ('clientes.listar', 'Listar clientes', TRUE),
      ('clientes.crear', 'Crear clientes', TRUE),
      (
        'clientes.restaurar',
        'Restaurar clientes inactivos',
        TRUE
      ),
      ('clientes.eliminar', 'Eliminar clientes', TRUE),
      (
        'bajas_cliente.rechazar',
        'Rechazar solicitudes de baja/reactivación de cliente',
        TRUE
      ),
      (
        'bajas_cliente.solicitar',
        'Solicitar baja o reactivación de cliente',
        TRUE
      ),
      (
        'bajas_cliente.listar',
        'Listar solicitudes de baja/reactivación de cliente',
        TRUE
      ),
      (
        'bajas_cliente.ver',
        'Ver detalle de solicitud de baja de cliente',
        TRUE
      ),
      (
        'bajas_cliente.aprobar',
        'Aprobar solicitudes de baja/reactivación de cliente',
        TRUE
      ),
      (
        'bajas_cliente.eliminar',
        'Eliminar solicitudes de baja de cliente',
        TRUE
      ),
      (
        'contactos.crear',
        'Crear contactos de clientes',
        TRUE
      ),
      (
        'direcciones.listar',
        'Listar direcciones de clientes',
        TRUE
      ),
      (
        'contactos.ver',
        'Ver detalle de contactos de clientes',
        TRUE
      ),
      (
        'direcciones.editar',
        'Editar direcciones de clientes',
        TRUE
      ),
      (
        'direcciones.ver',
        'Ver detalle de direcciones de clientes',
        TRUE
      ),
      (
        'contactos.editar',
        'Editar contactos de clientes',
        TRUE
      ),
      (
        'contactos.eliminar',
        'Eliminar contactos de clientes',
        TRUE
      ),
      (
        'contactos.listar',
        'Listar contactos de clientes',
        TRUE
      ),
      (
        'direcciones.eliminar',
        'Eliminar direcciones de clientes',
        TRUE
      ),
      (
        'direcciones.crear',
        'Crear direcciones de clientes',
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
