/* CREATE OR REPLACE FUNCTION cli_actualizar_por_id_cliente(
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
    p_id_usuario_auditoria                  INT      DEFAULT NULL
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
        id_usuario_modificacion     = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion          = NOW()
    WHERE id = p_id;

    RETURN cli_obtener_por_id_cliente(p_id);
END;
$$; */

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
    p_telefono                    VARCHAR  DEFAULT NULL,
    p_email                       VARCHAR  DEFAULT NULL,
    p_es_agente_percepcion        BOOLEAN  DEFAULT NULL,
    p_es_buen_contribuyente       BOOLEAN  DEFAULT NULL,
    p_es_agente_retenedor         BOOLEAN  DEFAULT NULL,
    p_afecto_rus                  BOOLEAN  DEFAULT NULL,
    p_situacion_sunat             VARCHAR  DEFAULT NULL,
    p_estado_contribuyente_sunat  VARCHAR  DEFAULT NULL,
    p_observacion                 VARCHAR  DEFAULT NULL,
    p_direccion                   VARCHAR  DEFAULT NULL,
    p_referencia                  VARCHAR  DEFAULT NULL,
    p_id_departamento             INT      DEFAULT NULL,
    p_id_provincia                INT      DEFAULT NULL,
    p_id_distrito                 INT      DEFAULT NULL,
    p_id_pais                     INT      DEFAULT NULL,
    p_id_usuario_auditoria                  INT      DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_direccion INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id) THEN
        RETURN json_build_object('error', 'No existe un cliente con id ' || p_id, 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro cliente registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro cliente con el código interno ' || p_codigo_interno, 'registro', NULL);
    END IF;

    BEGIN
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
            telefono                    = COALESCE(p_telefono, telefono),
            email                       = COALESCE(p_email, email),
            es_agente_percepcion        = COALESCE(p_es_agente_percepcion, es_agente_percepcion),
            es_buen_contribuyente       = COALESCE(p_es_buen_contribuyente, es_buen_contribuyente),
            es_agente_retenedor         = COALESCE(p_es_agente_retenedor, es_agente_retenedor),
            afecto_rus                  = COALESCE(p_afecto_rus, afecto_rus),
            situacion_sunat             = COALESCE(p_situacion_sunat, situacion_sunat),
            estado_contribuyente_sunat  = COALESCE(p_estado_contribuyente_sunat, estado_contribuyente_sunat),
            observacion                 = COALESCE(p_observacion, observacion),
            id_usuario_modificacion     = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion          = NOW()
        WHERE id = p_id;
        IF p_direccion IS NOT NULL OR p_referencia IS NOT NULL OR p_id_departamento IS NOT NULL
           OR p_id_provincia IS NOT NULL OR p_id_distrito IS NOT NULL OR p_id_pais IS NOT NULL THEN

            SELECT id INTO v_id_direccion
            FROM cli_direcciones
            WHERE id_cliente = p_id AND es_principal = TRUE AND estado = 1
            ORDER BY id DESC
            LIMIT 1;

            IF v_id_direccion IS NOT NULL THEN
                UPDATE cli_direcciones SET
                    direccion               = COALESCE(p_direccion, direccion),
                    referencia              = COALESCE(p_referencia, referencia),
                    id_departamento         = COALESCE(p_id_departamento, id_departamento),
                    id_provincia            = COALESCE(p_id_provincia, id_provincia),
                    id_distrito             = COALESCE(p_id_distrito, id_distrito),
                    id_pais                 = COALESCE(p_id_pais, id_pais),
                    id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
                    fecha_modificacion      = NOW()
                WHERE id = v_id_direccion;
            ELSE
                INSERT INTO cli_direcciones (
                    id_cliente, direccion, referencia,
                    id_departamento, id_provincia, id_distrito, id_pais,
                    es_principal, estado,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id, p_direccion, p_referencia,
                    p_id_departamento, p_id_provincia, p_id_distrito, p_id_pais,
                    TRUE, 1,
                    p_id_usuario_auditoria, p_id_usuario_auditoria
                );
            END IF;
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados (documento o código interno)', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de ubicación o clasificación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el cliente: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN cli_obtener_por_id_cliente(p_id);
END;
$$;