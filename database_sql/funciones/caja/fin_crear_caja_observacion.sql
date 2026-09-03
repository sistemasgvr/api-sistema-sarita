-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_crear_caja_observacion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS fin_crear_caja_observacion(p_fecha date, p_texto character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_crear_caja_observacion(p_fecha date, p_texto character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INT;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL OR NULLIF(TRIM(p_texto), '') IS NULL THEN
        RETURN json_build_object('error', 'Fecha y texto son obligatorios', 'registro', NULL);
    END IF;

    INSERT INTO fin_caja_observacion (fecha, texto, id_usuario_creacion)
    VALUES (p_fecha, TRIM(p_texto), p_id_usuario)
    RETURNING id INTO v_id;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            o.id, o.fecha, o.texto,
            o.id_usuario_creacion AS "idUsuarioCreacion",
            u.nombre AS "usuario",
            o.fecha_creacion AS "fechaCreacion"
        FROM fin_caja_observacion o
        LEFT JOIN auth_usuarios u ON u.id = o.id_usuario_creacion
        WHERE o.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
