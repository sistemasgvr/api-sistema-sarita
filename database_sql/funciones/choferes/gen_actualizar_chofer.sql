DROP FUNCTION IF EXISTS gen_actualizar_chofer(INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_chofer(
    p_id                    INTEGER,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_nombres               VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
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
    v_id_licencia INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM gen_chofer WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un chofer con id ' || p_id);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_chofer WHERE numero_documento = p_numero_documento AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro chofer registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        UPDATE gen_chofer
        SET
            id_cliente = COALESCE(p_id_cliente, id_cliente),
            apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
            apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
            nombres = COALESCE(p_nombres, nombres),
            id_tipo_documento = COALESCE(p_id_tipo_documento, id_tipo_documento),
            numero_documento = COALESCE(p_numero_documento, numero_documento),
            telefono = COALESCE(p_telefono, telefono),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id AND estado = 1;

        IF p_codigo_licencia IS NOT NULL OR p_fecha_emision IS NOT NULL OR p_fecha_vencimiento IS NOT NULL
           OR p_id_tipo_licencia IS NOT NULL OR p_id_categoria_licencia IS NOT NULL THEN

            SELECT id INTO v_id_licencia
            FROM gen_licencia
            WHERE id_chofer = p_id AND estado = 1
            ORDER BY fecha_emision DESC, id DESC
            LIMIT 1;

            IF v_id_licencia IS NOT NULL THEN
                UPDATE gen_licencia SET
                    codigo                  = COALESCE(p_codigo_licencia, codigo),
                    fecha_emision           = COALESCE(p_fecha_emision, fecha_emision),
                    fecha_vencimiento       = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
                    id_tipo_licencia        = COALESCE(p_id_tipo_licencia, id_tipo_licencia),
                    id_categoria_licencia   = COALESCE(p_id_categoria_licencia, id_categoria_licencia),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion      = NOW()
                WHERE id = v_id_licencia;
            ELSIF p_codigo_licencia IS NOT NULL AND p_fecha_emision IS NOT NULL AND p_fecha_vencimiento IS NOT NULL THEN
                INSERT INTO gen_licencia (
                    id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
                    fecha_emision, fecha_vencimiento,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id_tipo_licencia, p_id_categoria_licencia, p_id, p_codigo_licencia,
                    p_fecha_emision, p_fecha_vencimiento,
                    p_id_usuario_auditoria, p_id_usuario_auditoria
                );
            END IF;
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de tipo o categoría no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el chofer: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN gen_obtener_chofer(p_id);
END;
$function$;
/* DROP FUNCTION IF EXISTS gen_actualizar_chofer(
   INTEGER,
   INTEGER,
   VARCHAR,
   VARCHAR,
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   INTEGER
);
CREATE OR REPLACE FUNCTION gen_actualizar_chofer(
    p_id                    INTEGER,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_nombres               VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_chofer
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        nombres = COALESCE(p_nombres, nombres),
        id_tipo_documento = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_chofer(p_id);
END;
$function$;
 */