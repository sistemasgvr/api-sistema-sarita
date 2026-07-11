DROP FUNCTION IF EXISTS gen_crear_chofer(VARCHAR, INTEGER, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION gen_crear_chofer(
    p_nombres               VARCHAR,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    -- licencia
    p_codigo_licencia       VARCHAR DEFAULT NULL,
    p_fecha_emision         DATE    DEFAULT NULL,
    p_fecha_vencimiento     DATE    DEFAULT NULL,
    p_id_tipo_licencia      INTEGER DEFAULT NULL,
    p_id_categoria_licencia INTEGER DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_chofer INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_chofer WHERE numero_documento = p_numero_documento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe un chofer registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO gen_chofer (
            id_cliente, apellido_paterno, apellido_materno, nombres,
            id_tipo_documento, numero_documento, telefono,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_cliente, p_apellido_paterno, p_apellido_materno, p_nombres,
            p_id_tipo_documento, p_numero_documento, p_telefono,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_chofer;

        -- Licencia (opcional al crear el chofer)
        IF p_codigo_licencia IS NOT NULL THEN
            INSERT INTO gen_licencia (
                id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
                fecha_emision, fecha_vencimiento,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id_tipo_licencia, p_id_categoria_licencia, v_id_chofer, p_codigo_licencia,
                p_fecha_emision, p_fecha_vencimiento,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            );
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados (documento o código de licencia)', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de cliente, tipo o categoría no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el chofer: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN gen_obtener_chofer(v_id_chofer);
END;
$function$;
/* DROP FUNCTION IF EXISTS gen_crear_chofer(
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   VARCHAR,
   INTEGER
);
CREATE OR REPLACE FUNCTION gen_crear_chofer(
    p_nombres               VARCHAR,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_chofer (
        id_cliente, apellido_paterno, apellido_materno, nombres,
        id_tipo_documento, numero_documento,telefono,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_apellido_paterno, p_apellido_materno, p_nombres,
        p_id_tipo_documento, p_numero_documento, p_telefono,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_chofer(v_id);
END;
$function$;
 */