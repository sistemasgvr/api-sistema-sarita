-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_upsert_facturacion_apisperu
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS gen_upsert_facturacion_apisperu(p_habilitado boolean, p_url character varying, p_token text, p_timeout_ms integer, p_client_id character varying, p_client_secret character varying, p_ruc_emisor character varying, p_usuario character varying, p_contrasena character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_upsert_facturacion_apisperu(p_habilitado boolean DEFAULT true, p_url character varying DEFAULT NULL::character varying, p_token text DEFAULT NULL::text, p_timeout_ms integer DEFAULT NULL::integer, p_client_id character varying DEFAULT NULL::character varying, p_client_secret character varying DEFAULT NULL::character varying, p_ruc_emisor character varying DEFAULT NULL::character varying, p_usuario character varying DEFAULT NULL::character varying, p_contrasena character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_empresa INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- p_usuario / p_contrasena / p_ruc_emisor se ignoran aquí:
    -- el RUC vive en gen_empresa; usuario/clave SOL se editan en la pantalla SUNAT.

    SELECT cs.id, cs.id_empresa INTO v_id, v_id_empresa
    FROM gen_configuracion_sunat cs
    WHERE cs.estado = 1
    ORDER BY cs.id
    LIMIT 1;

    IF v_id IS NULL THEN
        SELECT id INTO v_id_empresa
        FROM gen_empresa
        WHERE estado = 1
        ORDER BY id
        LIMIT 1;

        IF v_id_empresa IS NULL THEN
            RETURN json_build_object(
              'registro', NULL,
              'error', 'No hay empresa registrada. Configura Empresa primero.'
            );
        END IF;

        INSERT INTO gen_configuracion_sunat (
            id_empresa,
            usuario_sol,
            clave_sol,
            apisperu_habilitado,
            apisperu_url,
            apisperu_token,
            apisperu_timeout_ms,
            client_id_gre,
            client_secret_gre,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            v_id_empresa,
            NULL,
            NULL,
            COALESCE(p_habilitado, TRUE),
            NULLIF(TRIM(COALESCE(p_url, '')), ''),
            NULLIF(TRIM(COALESCE(p_token, '')), ''),
            COALESCE(p_timeout_ms, 60000),
            NULLIF(TRIM(COALESCE(p_client_id, '')), ''),
            NULLIF(TRIM(COALESCE(p_client_secret, '')), ''),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE gen_configuracion_sunat
        SET
            apisperu_habilitado = COALESCE(p_habilitado, apisperu_habilitado),
            apisperu_url = COALESCE(NULLIF(TRIM(COALESCE(p_url, '')), ''), apisperu_url),
            apisperu_token = CASE
                WHEN p_token IS NULL OR TRIM(p_token) = '' THEN apisperu_token
                ELSE TRIM(p_token)
            END,
            apisperu_timeout_ms = COALESCE(p_timeout_ms, apisperu_timeout_ms),
            client_id_gre = CASE
                WHEN p_client_id IS NULL THEN client_id_gre
                WHEN TRIM(p_client_id) = '' THEN NULL
                ELSE TRIM(p_client_id)
            END,
            client_secret_gre = CASE
                WHEN p_client_secret IS NULL OR TRIM(p_client_secret) = '' THEN client_secret_gre
                ELSE TRIM(p_client_secret)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id;
    END IF;

    RETURN gen_obtener_facturacion_apisperu();
END;
$function$;
