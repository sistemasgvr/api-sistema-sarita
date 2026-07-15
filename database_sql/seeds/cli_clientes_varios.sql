-- Cliente genérico de mostrador (walk-in) para Nota de venta / ventas sin datos.
-- Lookup estable: codigo_interno = 'CVARIOS'

INSERT INTO cli_clientes (
    codigo_interno,
    razon_social,
    id_tipo_cliente,
    id_tipo_persona,
    nombres,
    id_tipo_documento,
    numero_documento,
    estado,
    observacion
)
SELECT
    'CVARIOS',
    'CLIENTES VARIOS',
    (
        SELECT lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoCliente'
          AND lo.estado = 1
          AND (
            upper(lo.nombre) = 'CLIENTE'
            OR upper(lo.nombre) LIKE '%CLIENTE%'
          )
        ORDER BY lo.id
        LIMIT 1
    ),
    (
        SELECT lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoPersona'
          AND lo.estado = 1
          AND upper(lo.nombre) LIKE '%NATURAL%'
        ORDER BY lo.id
        LIMIT 1
    ),
    'CLIENTES VARIOS',
    (
        SELECT lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumento'
          AND lo.estado = 1
          AND upper(lo.nombre) = 'DNI'
        ORDER BY lo.id
        LIMIT 1
    ),
    '00000000',
    1,
    'Cliente genérico de mostrador. No usar en factura electrónica.'
WHERE NOT EXISTS (
    SELECT 1 FROM cli_clientes WHERE codigo_interno = 'CVARIOS'
);
