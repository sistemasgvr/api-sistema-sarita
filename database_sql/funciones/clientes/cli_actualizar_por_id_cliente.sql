CREATE OR REPLACE FUNCTION cli_actualizar_por_id_cliente(
    p_id                          INT,
    p_codigo_interno              varchar  DEFAULT NULL,
    p_razon_social                varchar  DEFAULT NULL,
    p_id_tipo_cliente              INT      DEFAULT NULL,
    p_id_tipo_persona              INT      DEFAULT NULL,
    p_nombres                     varchar  DEFAULT NULL,
    p_apellido_paterno             varchar  DEFAULT NULL,
    p_apellido_materno             varchar  DEFAULT NULL,
    p_id_tipo_documento            INT      DEFAULT NULL,
    p_numero_documento             varchar  DEFAULT NULL,
    p_direccion                   varchar  DEFAULT NULL,
    p_referencia                  varchar  DEFAULT NULL,
    p_telefono                    varchar  DEFAULT NULL,
    p_email                       varchar  DEFAULT NULL,
    p_id_departamento              INT      DEFAULT NULL,
    p_id_provincia                 INT      DEFAULT NULL,
    p_id_distrito                  INT      DEFAULT NULL,
    p_id_pais                     INT      DEFAULT NULL,
    p_es_agente_percepcion         BOOLEAN  DEFAULT NULL,
    p_es_buen_contribuyente        BOOLEAN  DEFAULT NULL,
    p_es_agente_retenedor          BOOLEAN  DEFAULT NULL,
    p_afecto_rus                  BOOLEAN  DEFAULT NULL,
    p_situacion_sunat              varchar  DEFAULT NULL,
    p_estado_contribuyente_sunat   varchar  DEFAULT NULL,
    p_observacion                 varchar  DEFAULT NULL,
    p_id_usuario                  INT      DEFAULT NULL  -- usuario que modifica (auditoría)
)
RETURNS SETOF cli_clientes
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id) THEN
        RAISE EXCEPTION 'No existe un cliente con id %', p_id;
    END IF;

    -- Validación: documento único, excluyendo el propio registro
    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento AND id <> p_id
    ) THEN
        RAISE EXCEPTION 'Ya existe otro cliente registrado con el documento %', p_numero_documento;
    END IF;

    -- Validación: código interno único, excluyendo el propio registro
    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno AND id <> p_id
    ) THEN
        RAISE EXCEPTION 'Ya existe otro cliente con el código interno %', p_codigo_interno;
    END IF;

    RETURN QUERY
    UPDATE cli_clientes SET
        codigo_interno              = COALESCE(p_codigo_interno, codigo_interno),
        razon_social                = COALESCE(p_razon_social, razon_social),
        id_tipo_cliente              = COALESCE(p_id_tipo_cliente, id_tipo_cliente),
        id_tipo_persona              = COALESCE(p_id_tipo_persona, id_tipo_persona),
        nombres                     = COALESCE(p_nombres, nombres),
        apellido_paterno             = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno             = COALESCE(p_apellido_materno, apellido_materno),
        id_tipo_documento            = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento             = COALESCE(p_numero_documento, numero_documento),
        direccion                   = COALESCE(p_direccion, direccion),
        referencia                  = COALESCE(p_referencia, referencia),
        telefono                    = COALESCE(p_telefono, telefono),
        email                       = COALESCE(p_email, email),
        id_departamento              = COALESCE(p_id_departamento, id_departamento),
        id_provincia                 = COALESCE(p_id_provincia, id_provincia),
        id_distrito                  = COALESCE(p_id_distrito, id_distrito),
        id_pais                     = COALESCE(p_id_pais, id_pais),
        es_agente_percepcion         = COALESCE(p_es_agente_percepcion, es_agente_percepcion),
        es_buen_contribuyente        = COALESCE(p_es_buen_contribuyente, es_buen_contribuyente),
        es_agente_retenedor          = COALESCE(p_es_agente_retenedor, es_agente_retenedor),
        afecto_rus                  = COALESCE(p_afecto_rus, afecto_rus),
        situacion_sunat              = COALESCE(p_situacion_sunat, situacion_sunat),
        estado_contribuyente_sunat   = COALESCE(p_estado_contribuyente_sunat, estado_contribuyente_sunat),
        observacion                 = COALESCE(p_observacion, observacion),
        id_usuario_modificacion      = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion           = NOW()
    WHERE id = p_id
    RETURNING *;
END;
$$;