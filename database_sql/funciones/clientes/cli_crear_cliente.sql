CREATE OR REPLACE FUNCTION cli_crear_cliente(
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
    p_es_agente_percepcion        BOOLEAN  DEFAULT FALSE,
    p_es_buen_contribuyente       BOOLEAN  DEFAULT FALSE,
    p_es_agente_retenedor         BOOLEAN  DEFAULT FALSE,
    p_afecto_rus                  BOOLEAN  DEFAULT FALSE,
    p_situacion_sunat             VARCHAR  DEFAULT NULL,
    p_estado_contribuyente_sunat  VARCHAR  DEFAULT NULL,
    p_observacion                 VARCHAR  DEFAULT NULL,
    p_direccion                   VARCHAR  DEFAULT NULL,
    p_referencia                  VARCHAR  DEFAULT NULL,
    p_latitud                     NUMERIC(10,8) DEFAULT NULL,
    p_longitud                    NUMERIC(11,8) DEFAULT NULL,
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
    v_id_cliente INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_razon_social IS NULL AND p_nombres IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar razon_social o nombres del cliente', 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento
    ) THEN
        RETURN json_build_object('error', 'Ya existe un cliente registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    IF p_codigo_interno IS NOT NULL AND EXISTS (
        SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno
    ) THEN
        RETURN json_build_object('error', 'Ya existe un cliente con el código interno ' || p_codigo_interno, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO cli_clientes (
            codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
            nombres, apellido_paterno, apellido_materno,
            id_tipo_documento, numero_documento,
            telefono, email,
            es_agente_percepcion, es_buen_contribuyente, es_agente_retenedor, afecto_rus,
            situacion_sunat, estado_contribuyente_sunat, observacion,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_codigo_interno, p_razon_social, p_id_tipo_cliente, p_id_tipo_persona,
            p_nombres, p_apellido_paterno, p_apellido_materno,
            p_id_tipo_documento, p_numero_documento,
            p_telefono, p_email,
            p_es_agente_percepcion, p_es_buen_contribuyente, p_es_agente_retenedor, p_afecto_rus,
            p_situacion_sunat, p_estado_contribuyente_sunat, p_observacion,
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_cliente;

        IF p_direccion IS NOT NULL THEN
            INSERT INTO cli_direcciones (
                id_cliente, direccion, referencia, latitud, longitud,
                id_departamento, id_provincia, id_distrito, id_pais,
                es_principal, estado,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                v_id_cliente, p_direccion, p_referencia, p_latitud, p_longitud,
                p_id_departamento, p_id_provincia, p_id_distrito, p_id_pais,
                TRUE, 1,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            );
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados (documento o código interno)', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de ubicación o clasificación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el cliente: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN cli_obtener_por_id_cliente(v_id_cliente);
END;
$$;
/* CREATE OR REPLACE FUNCTION cli_crear_clientes(
p_codigo_interno              VARCHAR  DEFAULT NULL,
p_razon_social                VARCHAR  DEFAULT NULL,
p_id_tipo_cliente             INT      DEFAULT NULL,
p_id_tipo_persona             INT      DEFAULT NULL,
p_nombres                     VARCHAR  DEFAULT NULL,
p_apellido_paterno            VARCHAR  DEFAULT NULL,
p_apellido_materno            VARCHAR  DEFAULT NULL,
p_id_tipo_documento           INT      DEFAULT NULL,
p_numero_documento            VARCHAR  DEFAULT NULL,
p_referencia                  VARCHAR  DEFAULT NULL,
p_telefono                    VARCHAR  DEFAULT NULL,
p_email                       VARCHAR  DEFAULT NULL,
p_es_agente_percepcion        BOOLEAN  DEFAULT FALSE,
p_es_buen_contribuyente       BOOLEAN  DEFAULT FALSE,
p_es_agente_retenedor         BOOLEAN  DEFAULT FALSE,
p_afecto_rus                  BOOLEAN  DEFAULT FALSE,
p_situacion_sunat             VARCHAR  DEFAULT NULL,
p_estado_contribuyente_sunat  VARCHAR  DEFAULT NULL,
p_observacion                 VARCHAR  DEFAULT NULL,
p_id_usuario_auditoria                  INT      DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
v_id INT;
BEGIN
SET TIME ZONE 'America/Lima';
IF p_razon_social IS NULL AND p_nombres IS NULL THEN
RETURN json_build_object('error', 'Debe indicar razon_social o nombres del cliente', 'registro', NULL);
END IF;

-- Validar que el documento sea único
IF p_numero_documento IS NOT NULL AND EXISTS (
SELECT 1 FROM cli_clientes WHERE numero_documento = p_numero_documento
) THEN
RETURN json_build_object('error', 'Ya existe un cliente registrado con el documento ' || p_numero_documento, 'registro', NULL);
END IF;

-- Validar que el código interno sea único
IF p_codigo_interno IS NOT NULL AND EXISTS (
SELECT 1 FROM cli_clientes WHERE codigo_interno = p_codigo_interno
) THEN
RETURN json_build_object('error', 'Ya existe un cliente con el código interno ' || p_codigo_interno, 'registro', NULL);
END IF;     

INSERT INTO cli_clientes (
codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
nombres, apellido_paterno, apellido_materno,
id_tipo_documento, numero_documento,
direccion, referencia, telefono, email,
es_agente_percepcion, es_buen_contribuyente, es_agente_retenedor, afecto_rus,
situacion_sunat, estado_contribuyente_sunat, observacion,
estado, id_usuario_creacion, id_usuario_modificacion
)
VALUES (
p_codigo_interno, p_razon_social, p_id_tipo_cliente, p_id_tipo_persona,
p_nombres, p_apellido_paterno, p_apellido_materno,
p_id_tipo_documento, p_numero_documento,
p_direccion, p_referencia, p_telefono, p_email,
p_es_agente_percepcion, p_es_buen_contribuyente, p_es_agente_retenedor, p_afecto_rus,
p_situacion_sunat, p_estado_contribuyente_sunat, p_observacion,
1, p_id_usuario_auditoria, p_id_usuario_auditoria
)
RETURNING id INTO v_id;

RETURN cli_obtener_por_id_cliente(v_id);
END;
$$; */