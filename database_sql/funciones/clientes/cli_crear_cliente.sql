CREATE OR REPLACE FUNCTION cli_crear_clientes(
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
    p_es_agente_percepcion         BOOLEAN  DEFAULT FALSE,
    p_es_buen_contribuyente        BOOLEAN  DEFAULT FALSE,
    p_es_agente_retenedor          BOOLEAN  DEFAULT FALSE,
    p_afecto_rus                  BOOLEAN  DEFAULT FALSE,
    p_situacion_sunat              varchar  DEFAULT NULL,
    p_estado_contribuyente_sunat   varchar  DEFAULT NULL,
    p_observacion                 varchar  DEFAULT NULL,
    p_id_usuario                  INT      DEFAULT NULL  -- usuario que crea (auditoría)
)
RETURNS SETOF cli_clientes
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar que se identifique al menos por razón social/nombres
    IF p_razon_social IS NULL AND p_nombres IS NULL THEN
        RAISE EXCEPTION 'Debe indicar razon_social o nombres del cliente';
    END IF;

    -- Validar que se identifique documento único (si se envía)
    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento
    ) THEN
        RAISE EXCEPTION 'Ya existe un cliente registrado con el documento %', p_numero_documento;
    END IF;

    -- Validar que se identifique código interno único (si se envía)
    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno
    ) THEN
        RAISE EXCEPTION 'Ya existe un cliente con el código interno %', p_codigo_interno;
    END IF;		

    RETURN QUERY
    INSERT INTO cli_clientes (
        codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
        nombres, apellido_paterno, apellido_materno,
        id_tipo_documento, numero_documento,
        direccion, referencia, telefono, email,
        id_departamento, id_provincia, id_distrito, id_pais,
        es_agente_percepcion, es_buen_contribuyente, es_agente_retenedor, afecto_rus,
        situacion_sunat, estado_contribuyente_sunat, observacion,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_codigo_interno, p_razon_social, p_id_tipo_cliente, p_id_tipo_persona,
        p_nombres, p_apellido_paterno, p_apellido_materno,
        p_id_tipo_documento, p_numero_documento,
        p_direccion, p_referencia, p_telefono, p_email,
        p_id_departamento, p_id_provincia, p_id_distrito, p_id_pais,
        p_es_agente_percepcion, p_es_buen_contribuyente, p_es_agente_retenedor, p_afecto_rus,
        p_situacion_sunat, p_estado_contribuyente_sunat, p_observacion,
        1, p_id_usuario, p_id_usuario
    )
    RETURNING *;
END;
$$;
