-- Cliente genérico de mostrador (Clientes Varios, codigo_interno CVARIOS)
INSERT INTO
  cli_clientes (
    codigo_interno,
    razon_social,
    nombres,
    apellido_paterno,
    apellido_materno,
    numero_documento,
    direccion,
    referencia,
    telefono,
    email,
    es_agente_percepcion,
    es_buen_contribuyente,
    es_agente_retenedor,
    afecto_rus,
    situacion_sunat,
    estado_contribuyente_sunat,
    observacion,
    estado,
    id_tipo_cliente,
    id_tipo_persona,
    id_tipo_documento
  )
VALUES
  (
    'CVARIOS',
    'CLIENTES VARIOS',
    'CLIENTES VARIOS',
    NULL,
    NULL,
    '00000000',
    NULL,
    NULL,
    NULL,
    NULL,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    NULL,
    NULL,
    'Cliente genérico de mostrador. No usar en factura electrónica.',
    1,
    (
      SELECT
        o.id
      FROM
        gen_lista_opciones o
        JOIN gen_lista l ON l.id = o.id_lista
      WHERE
        l.nombre = 'TipoCliente'
        AND o.nombre = 'Cliente'
      ORDER BY
        o.id
      LIMIT
        1
    ),
    (
      SELECT
        o.id
      FROM
        gen_lista_opciones o
        JOIN gen_lista l ON l.id = o.id_lista
      WHERE
        l.nombre = 'TipoPersona'
        AND o.nombre = 'Persona Natural'
      ORDER BY
        o.id
      LIMIT
        1
    ),
    (
      SELECT
        o.id
      FROM
        gen_lista_opciones o
        JOIN gen_lista l ON l.id = o.id_lista
      WHERE
        l.nombre = 'TipoDocumento'
        AND o.nombre = 'DNI'
      ORDER BY
        o.id
      LIMIT
        1
    )
  )
ON CONFLICT (codigo_interno) DO NOTHING;
