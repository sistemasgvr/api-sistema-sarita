-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: tra_listar_trabajadores
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.797Z
DROP FUNCTION IF EXISTS tra_listar_trabajadores(p_estado integer, p_buscar character varying, p_id_area integer, p_id_cargo integer, p_limite integer, p_offset integer, p_solo_sin_usuario boolean);

CREATE OR REPLACE FUNCTION tra_listar_trabajadores(p_estado integer DEFAULT NULL::integer, p_buscar character varying DEFAULT ''::character varying, p_id_area integer DEFAULT NULL::integer, p_id_cargo integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_solo_sin_usuario boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM tra_trabajadores t
    LEFT JOIN auth_usuarios au ON au.id_trabajador = t.id AND au.estado = TRUE
    WHERE (p_estado IS NULL OR t.estado = p_estado)
      AND (p_id_area IS NULL OR t.id_area = p_id_area)
      AND (p_id_cargo IS NULL OR t.id_cargo = p_id_cargo)
      AND (NOT p_solo_sin_usuario OR au.id IS NULL)
      AND (
          p_buscar = ''
          OR gen_texto_coincide(t.nombres, p_buscar)
          OR gen_texto_coincide(COALESCE(t.apellido_paterno, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(t.apellido_materno, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(t.numero_documento, ''), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            t.id,
            t.nombres,
            t.apellido_paterno,
            t.apellido_materno,
            t.id_tipo_documento,
            td.nombre  AS nombre_tipo_documento,
    t.numero_documento,
    t.correo,
    t.direccion,
            t.referencia,
            t.latitud,
            t.longitud,
            t.id_pais,
            t.id_departamento,
            t.id_provincia,
            t.id_distrito,
            t.fecha_nacimiento,
            CASE
                WHEN t.fecha_nacimiento IS NULL THEN NULL
                ELSE DATE_PART('year', AGE(CURRENT_DATE, t.fecha_nacimiento))::INT
            END AS edad,
            t.fecha_inicio,
            t.fecha_cese,
            t.id_area,
            a.nombre   AS nombre_area,
            t.id_cargo,
            c.nombre   AS nombre_cargo,
            au.id      AS id_usuario,
            au.nombre  AS nombre_usuario_vinculo,
            (au.id IS NOT NULL) AS es_usuario,
            ch.id      AS id_chofer,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer,
            (ch.id IS NOT NULL) AS es_chofer,
            t.estado,
            t.fecha_creacion,
            t.fecha_modificacion
        FROM tra_trabajadores t
        LEFT JOIN gen_lista_opciones td ON t.id_tipo_documento = td.id
        LEFT JOIN gen_lista_opciones a  ON t.id_area = a.id
        LEFT JOIN gen_lista_opciones c  ON t.id_cargo = c.id
        LEFT JOIN auth_usuarios au      ON au.id_trabajador = t.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch         ON ch.id_trabajador = t.id AND ch.estado = 1
        WHERE (p_estado IS NULL OR t.estado = p_estado)
          AND (p_id_area IS NULL OR t.id_area = p_id_area)
          AND (p_id_cargo IS NULL OR t.id_cargo = p_id_cargo)
          AND (NOT p_solo_sin_usuario OR au.id IS NULL)
          AND (
              p_buscar = ''
              OR gen_texto_coincide(t.nombres, p_buscar)
              OR gen_texto_coincide(COALESCE(t.apellido_paterno, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(t.apellido_materno, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(t.numero_documento, ''), p_buscar)
          )
        ORDER BY t.nombres ASC
        LIMIT p_limite
        OFFSET p_offset
    ) r;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$
