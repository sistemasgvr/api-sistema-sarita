-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_archivo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_archivo(p_nombre_original character varying, p_nombre_almacenado character varying, p_ruta character varying, p_bucket character varying, p_mime_type character varying, p_extension character varying, p_tamanio_bytes bigint, p_id_empresa integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_archivo(p_nombre_original character varying, p_nombre_almacenado character varying, p_ruta character varying, p_bucket character varying, p_mime_type character varying DEFAULT NULL::character varying, p_extension character varying DEFAULT NULL::character varying, p_tamanio_bytes bigint DEFAULT NULL::bigint, p_id_empresa integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_archivo (
        nombre_original,
        nombre_almacenado,
        ruta,
        bucket,
        mime_type,
        extension,
        tamanio_bytes,
        id_empresa,
        estado,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_nombre_original,
        p_nombre_almacenado,
        p_ruta,
        p_bucket,
        p_mime_type,
        p_extension,
        p_tamanio_bytes,
        p_id_empresa,
        1,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    ON CONFLICT (bucket, ruta) DO UPDATE
    SET
        nombre_original = EXCLUDED.nombre_original,
        nombre_almacenado = EXCLUDED.nombre_almacenado,
        mime_type = EXCLUDED.mime_type,
        extension = EXCLUDED.extension,
        tamanio_bytes = EXCLUDED.tamanio_bytes,
        id_empresa = COALESCE(EXCLUDED.id_empresa, gen_archivo.id_empresa),
        estado = 1,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    RETURNING id INTO v_id;

    RETURN gen_obtener_archivo(v_id);
END;
$function$;
