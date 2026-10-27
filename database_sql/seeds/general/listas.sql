-- Listas y opciones del módulo general
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
      (1, 'TipoPersona', NULL, 1),
      (2, 'TipoCliente', NULL, 1),
      (3, 'TipoDocumento', NULL, 1),
      (
        7,
        'UnidadMedida',
        'Unidades de medida de productos',
        1
      ),
      (
        8,
        'AmbienteSunat',
        'Ambientes de facturación electrónica SUNAT',
        1
      ),
      (
        24,
        'EstadoGarantia',
        'Estados de garantía de envase',
        1
      ),
      (
        34,
        'TipoLicencia',
        'Tipo de licencia de conducir: vehículo pesado o ligero',
        1
      ),
      (
        35,
        'CategoriaLicencia',
        'Categoría SUTRAN de la licencia: A1, A2, A3, etc.',
        1
      ),
      (
        38,
        'TipoVehiculo',
        'Vehiculos para los clientes pueden 4x4, de dos ruedas,autos trailer',
        1
      ),
      (
        39,
        'EstadoVencimiento',
        'Estado de documentos con vencimiento: VIGENTE, POR_VENCER, VENCIDO',
        1
      ),
      (42, 'CategoriaVencimiento', NULL, 1),
      (
        46,
        'MotivoBajaCliente',
        'Motivos de baja de cliente',
        1
      ),
      (
        47,
        'EstadoAprobacion',
        'Estado de aprobación: PENDIENTE, APROBADA, RECHAZADA',
        1
      ),
      (
        51,
        'TipoSolicitud',
        'Estado para controlar las solicitudes de bajas del cliente',
        1
      ),
      (
        53,
        'TipoNotificacion',
        'Tipos de notificación del sistema',
        1
      ),
      (
        75,
        'EstadoProductoRecogido',
        'Estado del producto al recogerlo en una visita',
        1
      ),
      (
        79,
        'TipoValvula',
        'Tipo de válvula de cilindro',
        1
      ),
      (
        80,
        'SentidoAjuste',
        'Sentido del ajuste de inventario (Sumar / Restar)',
        1
      ),
      (
        81,
        'TipoItemMantenimiento',
        'Tipo de item en mantenimiento (Cilindro / Producto)',
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
      (1, 'TipoCliente', 'Cliente', NULL, 1),
      (2, 'TipoCliente', 'Paciente', NULL, 1),
      (3, 'TipoCliente', 'Proveedor', NULL, 1),
      (4, 'TipoDocumento', 'DNI', NULL, 1),
      (5, 'TipoDocumento', 'RUC', NULL, 1),
      (6, 'TipoDocumento', 'CE', NULL, 1),
      (7, 'UnidadMedida', 'KG', 'Kilogramo', 1),
      (8, 'UnidadMedida', 'MTS', 'Metro', 1),
      (9, 'UnidadMedida', 'UNID', 'Unidad', 1),
      (10, 'UnidadMedida', 'PAR', 'Par', 1),
      (11, 'UnidadMedida', 'MT3', 'Metro cúbico', 1),
      (12, 'UnidadMedida', 'GLN', 'Galón', 1),
      (13, 'UnidadMedida', 'LTR', 'Litro', 1),
      (
        22,
        'AmbienteSunat',
        'Producción',
        'Ambiente de producción SUNAT',
        1
      ),
      (44, 'AmbienteSunat', 'Desarrollo', 'Beta', 1),
      (113, 'TipoLicencia', 'VEHICULO_LIGERO', NULL, 1),
      (114, 'TipoLicencia', 'VEHICULO_PESADO', NULL, 1),
      (115, 'CategoriaLicencia', 'A-I', NULL, 1),
      (116, 'CategoriaLicencia', 'A-IIA', NULL, 1),
      (117, 'CategoriaLicencia', 'A-IIB', NULL, 1),
      (118, 'CategoriaLicencia', 'A-IIIA', NULL, 1),
      (119, 'CategoriaLicencia', 'A-IIIB', NULL, 1),
      (120, 'CategoriaLicencia', 'A-IIIC', NULL, 1),
      (
        124,
        'TipoVehiculo',
        'Automovil',
        'Vehiculo de 4 ruedas, normal',
        1
      ),
      (
        125,
        'TipoVehiculo',
        'MotoCard',
        'Moto de carga',
        1
      ),
      (
        126,
        'TipoVehiculo',
        ' Moto Lineal',
        'Moto de dos llantas',
        1
      ),
      (127, 'TipoVehiculo', 'Camioneta', '', 1),
      (
        131,
        'EstadoVencimiento',
        'VENCIDO',
        'Documento vencido',
        1
      ),
      (
        142,
        'CategoriaVencimiento',
        'INSPECCION',
        'Inspección Técnica Vehicular',
        1
      ),
      (
        143,
        'CategoriaVencimiento',
        'OTRO',
        'Otro tipo de documento',
        1
      ),
      (
        160,
        'MotivoBajaCliente',
        'OTROS',
        'Otro motivo',
        1
      ),
      (
        161,
        'MotivoBajaCliente',
        'FALLECIMIENTO',
        'Fallecimiento del titular',
        1
      ),
      (
        162,
        'EstadoAprobacion',
        'APROBADA',
        'Solicitud aprobada',
        1
      ),
      (
        163,
        'EstadoAprobacion',
        'RECHAZADA',
        'Solicitud rechazada',
        1
      ),
      (
        175,
        'TipoCliente',
        'Cliente / Proveedor',
        NULL,
        1
      ),
      (176, 'TipoPersona', 'Persona Natural', NULL, 1),
      (177, 'TipoPersona', 'Persona Jurídica', NULL, 1),
      (
        178,
        'TipoNotificacion',
        'ALQUILER_POR_VENCER',
        'Alquiler próximo a vencer',
        1
      ),
      (180, 'TipoSolicitud', 'BAJA', NULL, 1),
      (181, 'TipoSolicitud', 'REACTIVACION', NULL, 1),
      (192, 'CategoriaVencimiento', 'SOAT', 'SOAT', 1),
      (
        193,
        'CategoriaVencimiento',
        'MUNICIPAL',
        'Municipal',
        1
      ),
      (
        243,
        'EstadoVencimiento',
        'POR_VENCER',
        'Por vencer',
        1
      ),
      (244, 'EstadoVencimiento', 'VIGENTE', 'Vigente', 1),
      (
        245,
        'CategoriaVencimiento',
        'SEGURIDAD',
        'Seguridad',
        1
      ),
      (
        246,
        'CategoriaVencimiento',
        'CERTIFICADO',
        'Certificado',
        1
      ),
      (249, 'UnidadMedida', 'KGM', 'kg', 1),
      (
        250,
        'MotivoBajaCliente',
        'TRASLADO_ZONA',
        'Traslado de zona',
        1
      ),
      (
        251,
        'MotivoBajaCliente',
        'MAL_HISTORIAL',
        'Mal historial',
        1
      ),
      (
        252,
        'MotivoBajaCliente',
        'CIERRE_NEGOCIO',
        'Cierre de negocio',
        1
      ),
      (
        253,
        'MotivoBajaCliente',
        'SOLICITUD_CLIENTE',
        'Solicitud del cliente',
        1
      ),
      (
        254,
        'EstadoAprobacion',
        'PENDIENTE',
        'Pendiente',
        1
      ),
      (
        255,
        'TipoNotificacion',
        'ALQUILER_VENCIDO',
        'Alquiler vencido',
        1
      ),
      (256, 'TipoNotificacion', 'SISTEMA', 'Sistema', 1),
      (257, 'TipoNotificacion', 'USUARIO', 'Usuario', 1),
      (261, 'EstadoGarantia', 'DEVUELTA', 'Devuelta', 1),
      (262, 'EstadoGarantia', 'PARCIAL', 'Parcial', 1),
      (263, 'EstadoGarantia', 'ACTIVA', 'Activa', 1),
      (
        271,
        'TipoDocumento',
        'SD',
        'Cliente sin documento',
        1
      ),
      (286, 'UnidadMedida', 'PSI', 'PSI', 1),
      (287, 'UnidadMedida', 'LB', 'lb', 1),
      (288, 'UnidadMedida', 'BAR', 'bar', 1),
      (
        301,
        'CategoriaVencimiento',
        'DEFENSA_CIVIL',
        'Certificado / control de Defensa Civil',
        1
      ),
      (
        302,
        'CategoriaVencimiento',
        'EXTINTORES',
        'Control de vencimiento de extintores',
        1
      ),
      (
        303,
        'CategoriaVencimiento',
        'SANEAMIENTO_AMBIENTAL',
        'Certificado de Saneamiento Ambiental',
        1
      ),
      (
        304,
        'CategoriaVencimiento',
        'BPA',
        'Buenas Prácticas de Almacenamiento',
        1
      ),
      (
        305,
        'CategoriaVencimiento',
        'SALUBRIDAD',
        'Certificado de Salubridad',
        1
      ),
      (
        367,
        'EstadoProductoRecogido',
        'RECOGIDO',
        'Recogido conforme',
        1
      ),
      (
        368,
        'EstadoProductoRecogido',
        'NO_RECOGIDO',
        'No se pudo recoger',
        1
      ),
      (
        369,
        'EstadoProductoRecogido',
        'DANADO',
        'Recogido con daño',
        1
      ),
      (
        372,
        'EstadoGarantia',
        'TRANSFERIDA',
        'Garantía cerrada porque su saldo pasó al préstamo que renueva',
        1
      ),
      (378, 'SentidoAjuste', 'Sumar (+)', 'MAS', 1),
      (379, 'SentidoAjuste', 'Restar (-)', 'MENOS', 1),
      (
        380,
        'TipoItemMantenimiento',
        'Cilindro (balón)',
        'CILINDRO',
        1
      ),
      (
        381,
        'TipoItemMantenimiento',
        'Producto (regulador / accesorio)',
        'PRODUCTO',
        1
      ),
      (382, 'TipoValvula', 'Americana', 'AMERICANA', 1),
      (383, 'TipoValvula', 'China', 'CHINA', 1),
      (403, 'UnidadMedida', 'BLS', NULL, 1),
      (408, 'UnidadMedida', 'ROL', 'ROLLO', 1),
      (409, 'UnidadMedida', 'CA', 'CAJA', 1),
      (410, 'UnidadMedida', 'CJX50', NULL, 1),
      (411, 'UnidadMedida', 'PQT', 'PAQUETE', 1)
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
