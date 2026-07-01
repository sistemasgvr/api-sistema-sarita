CREATE OR REPLACE FUNCTION cli_actualizar_por_id_cliente(
    p_id                          INT,
    p_codigo_interno              VARCHAR  DEFAULT NULL,
    p_razon_social                VARCHAR  DEFAULT NULL,
    p_id_tipo_cliente             INT      DEFAULT NULL,
    p_id_tipo_persona             INT      DEFAULT NULL,
    p_nombres                     VARCHAR  DEFAULT NULL,
    p_apellido_paterno            VARCHAR  DEFAULT NULL,
    p_apellido_materno            VARCHAR  DEFAULT NULL,
    p_id_tipo_documento           INT      DEFAULT NULL,
    p_numero_documento            VARCHAR  DEFAULT NULL,
    p_direccion                   VARCHAR  DEFAULT NULL,
    p_referencia                  VARCHAR  DEFAULT NULL,
    p_telefono                    VARCHAR  DEFAULT NULL,
    p_email                       VARCHAR  DEFAULT NULL,
    p_id_departamento             INT      DEFAULT NULL,
    p_id_provincia                INT      DEFAULT NULL,
    p_id_distrito                 INT      DEFAULT NULL,
    p_id_pais                     INT      DEFAULT NULL,
    p_es_agente_percepcion        BOOLEAN  DEFAULT NULL,
    p_es_buen_contribuyente       BOOLEAN  DEFAULT NULL,
    p_es_agente_retenedor         BOOLEAN  DEFAULT NULL,
    p_afecto_rus                  BOOLEAN  DEFAULT NULL,
    p_situacion_sunat             VARCHAR  DEFAULT NULL,
    p_estado_contribuyente_sunat  VARCHAR  DEFAULT NULL,
    p_observacion                 VARCHAR  DEFAULT NULL,
    p_id_usuario                  INT      DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Validar existencia
    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id) THEN
        RETURN json_build_object('error', 'No existe un cliente con id ' || p_id, 'registro', NULL);
    END IF;

    -- Validación documento único
    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro cliente registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    -- Validación código interno único
    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro cliente con el código interno ' || p_codigo_interno, 'registro', NULL);
    END IF;

    -- Actualización
    UPDATE cli_clientes SET
        codigo_interno              = COALESCE(p_codigo_interno, codigo_interno),
        razon_social                = COALESCE(p_razon_social, razon_social),
        id_tipo_cliente             = COALESCE(p_id_tipo_cliente, id_tipo_cliente),
        id_tipo_persona             = COALESCE(p_id_tipo_persona, id_tipo_persona),
        nombres                     = COALESCE(p_nombres, nombres),
        apellido_paterno            = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno            = COALESCE(p_apellido_materno, apellido_materno),
        id_tipo_documento           = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento            = COALESCE(p_numero_documento, numero_documento),
        direccion                   = COALESCE(p_direccion, direccion),
        referencia                  = COALESCE(p_referencia, referencia),
        telefono                    = COALESCE(p_telefono, telefono),
        email                       = COALESCE(p_email, email),
        id_departamento             = COALESCE(p_id_departamento, id_departamento),
        id_provincia                = COALESCE(p_id_provincia, id_provincia),
        id_distrito                 = COALESCE(p_id_distrito, id_distrito),
        id_pais                     = COALESCE(p_id_pais, id_pais),
        es_agente_percepcion        = COALESCE(p_es_agente_percepcion, es_agente_percepcion),
        es_buen_contribuyente       = COALESCE(p_es_buen_contribuyente, es_buen_contribuyente),
        es_agente_retenedor         = COALESCE(p_es_agente_retenedor, es_agente_retenedor),
        afecto_rus                  = COALESCE(p_afecto_rus, afecto_rus),
        situacion_sunat             = COALESCE(p_situacion_sunat, situacion_sunat),
        estado_contribuyente_sunat  = COALESCE(p_estado_contribuyente_sunat, estado_contribuyente_sunat),
        observacion                 = COALESCE(p_observacion, observacion),
        id_usuario_modificacion     = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion          = NOW()
    WHERE id = p_id;

    RETURN cli_obtener_por_id_cliente(p_id);
END;
$$;