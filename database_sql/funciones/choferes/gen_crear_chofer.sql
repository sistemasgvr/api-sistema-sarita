-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_chofer
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.703Z
DROP FUNCTION IF EXISTS gen_crear_chofer(p_nombres character varying, p_id_cliente integer, p_id_trabajador integer, p_apellido_paterno character varying, p_apellido_materno character varying, p_id_tipo_documento integer, p_numero_documento character varying, p_telefono character varying, p_codigo_licencia character varying, p_fecha_emision date, p_fecha_vencimiento date, p_id_tipo_licencia integer, p_id_categoria_licencia integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_chofer(p_nombres character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_trabajador integer DEFAULT NULL::integer, p_apellido_paterno character varying DEFAULT NULL::character varying, p_apellido_materno character varying DEFAULT NULL::character varying, p_id_tipo_documento integer DEFAULT NULL::integer, p_numero_documento character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_codigo_licencia character varying DEFAULT NULL::character varying, p_fecha_emision date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_id_tipo_licencia integer DEFAULT NULL::integer, p_id_categoria_licencia integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_chofer INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL AND p_id_trabajador IS NULL THEN
        RETURN json_build_object('error', 'El chofer de flota propia debe vincularse a un trabajador.', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NOT NULL AND p_id_trabajador IS NOT NULL THEN
        RETURN json_build_object('error', 'Un chofer de cliente no puede vincularse a un trabajador de la empresa.', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NOT NULL AND p_nombres IS NULL THEN
        RETURN json_build_object('error', 'El nombre es obligatorio para choferes de cliente.', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El trabajador indicado no existe.', 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_chofer WHERE numero_documento = p_numero_documento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe un chofer registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO gen_chofer (
            id_cliente, id_trabajador, apellido_paterno, apellido_materno, nombres,
            id_tipo_documento, numero_documento, telefono,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_cliente, p_id_trabajador, p_apellido_paterno, p_apellido_materno, p_nombres,
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
$function$
