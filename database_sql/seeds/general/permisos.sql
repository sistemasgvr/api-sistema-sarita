-- Permisos del módulo general
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('empresas.listar', 'Listar empresas', TRUE),
      (
        'configuracion.ver',
        'Acceso al hub de configuración',
        TRUE
      ),
      ('almacenes.editar', 'Editar almacenes', TRUE),
      ('sucursales.ver', 'Ver detalle de sucursal', TRUE),
      ('almacenes.listar', 'Listar almacenes', TRUE),
      (
        'configuracion_sunat.editar',
        'Editar configuraciones SUNAT',
        TRUE
      ),
      (
        'configuracion_sunat.listar',
        'Listar configuraciones SUNAT',
        TRUE
      ),
      (
        'configuracion_servicios.eliminar',
        'Eliminar configuraciones de servicios',
        TRUE
      ),
      (
        'sucursales.eliminar',
        'Eliminar sucursales',
        TRUE
      ),
      ('sucursales.listar', 'Listar sucursales', TRUE),
      (
        'condiciones_pago.editar',
        'Editar condiciones de pago',
        TRUE
      ),
      ('empresas.editar', 'Editar empresas', TRUE),
      (
        'configuracion_servicios.crear',
        'Crear configuraciones de servicios',
        TRUE
      ),
      ('empresas.ver', 'Ver detalle de empresa', TRUE),
      (
        'configuracion_sunat.eliminar',
        'Eliminar configuraciones SUNAT',
        TRUE
      ),
      ('empresas.eliminar', 'Eliminar empresas', TRUE),
      ('sucursales.editar', 'Editar sucursales', TRUE),
      ('empresas.crear', 'Crear empresas', TRUE),
      (
        'configuracion_servicios.ver',
        'Ver detalle de configuración de servicio',
        TRUE
      ),
      (
        'configuracion_servicios.listar',
        'Listar configuraciones de servicios',
        TRUE
      ),
      ('sucursales.crear', 'Crear sucursales', TRUE),
      (
        'configuracion_sunat.crear',
        'Crear configuraciones SUNAT',
        TRUE
      ),
      (
        'configuracion_sunat.ver',
        'Ver detalle de configuración SUNAT',
        TRUE
      ),
      (
        'condiciones_pago.eliminar',
        'Eliminar condiciones de pago',
        TRUE
      ),
      ('almacenes.crear', 'Crear almacenes', TRUE),
      (
        'configuracion_servicios.editar',
        'Editar configuraciones de servicios',
        TRUE
      ),
      ('almacenes.eliminar', 'Eliminar almacenes', TRUE),
      (
        'condiciones_pago.listar',
        'Listar condiciones de pago',
        TRUE
      ),
      (
        'condiciones_pago.crear',
        'Crear condiciones de pago',
        TRUE
      ),
      ('almacenes.ver', 'Ver detalle de almacén', TRUE),
      (
        'condiciones_pago.ver',
        'Ver detalle de condición de pago',
        TRUE
      ),
      (
        'actividades.ranking',
        'Ver el ranking de actividades por colaborador',
        TRUE
      ),
      (
        'actividades.verificar',
        'Verificar por escaneo los ítems de una actividad',
        TRUE
      ),
      ('choferes.listar', 'Listar choferes', TRUE),
      (
        'licencias.crear',
        'Crear licencias de conducir',
        TRUE
      ),
      ('choferes.crear', 'Crear choferes', TRUE),
      (
        'licencias.listar',
        'Listar licencias de conducir',
        TRUE
      ),
      ('actividades.crear', 'Crear actividades', TRUE),
      (
        'actividades.ver',
        'Ver detalle de actividades',
        TRUE
      ),
      ('actividades.listar', 'Listar actividades', TRUE),
      (
        'documentos_vencimiento.ver',
        'Ver detalle de permisos y certificados (vencimientos)',
        TRUE
      ),
      (
        'catalogos.editar',
        'Editar catálogos (listas maestras)',
        TRUE
      ),
      (
        'documentos_vencimiento.editar',
        'Editar permisos y certificados (vencimientos)',
        TRUE
      ),
      (
        'actividades.eliminar',
        'Eliminar actividades',
        TRUE
      ),
      (
        'cuentas_bancarias.crear',
        'Crear cuentas bancarias',
        TRUE
      ),
      (
        'licencias.eliminar',
        'Eliminar licencias de conducir',
        TRUE
      ),
      (
        'licencias.editar',
        'Editar licencias de conducir',
        TRUE
      ),
      ('actividades.editar', 'Editar actividades', TRUE),
      ('choferes.eliminar', 'Eliminar choferes', TRUE),
      ('vehiculos.crear', 'Crear vehículos', TRUE),
      ('vehiculos.ver', 'Ver detalle de vehículos', TRUE),
      ('vehiculos.editar', 'Editar vehículos', TRUE),
      (
        'licencias.ver',
        'Ver detalle de licencias de conducir',
        TRUE
      ),
      ('vehiculos.listar', 'Listar vehículos', TRUE),
      (
        'documentos_vencimiento.eliminar',
        'Eliminar permisos y certificados (vencimientos)',
        TRUE
      ),
      ('choferes.ver', 'Ver detalle de choferes', TRUE),
      ('choferes.editar', 'Editar choferes', TRUE),
      (
        'documentos_vencimiento.listar',
        'Listar permisos y certificados (vencimientos)',
        TRUE
      ),
      (
        'cuentas_bancarias.ver',
        'Ver detalle de cuentas bancarias',
        TRUE
      ),
      (
        'documentos_vencimiento.crear',
        'Crear permisos y certificados (vencimientos)',
        TRUE
      ),
      ('vehiculos.eliminar', 'Eliminar vehículos', TRUE),
      (
        'cuentas_bancarias.listar',
        'Listar cuentas bancarias',
        TRUE
      ),
      (
        'cuentas_bancarias.eliminar',
        'Eliminar cuentas bancarias',
        TRUE
      ),
      (
        'cuentas_bancarias.editar',
        'Editar cuentas bancarias',
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
