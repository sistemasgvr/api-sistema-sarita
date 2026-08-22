CREATE OR REPLACE FUNCTION tra_obtener_trabajador(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            t.id,
            t.nombres,
            t.apellido_paterno,
            t.apellido_materno,
            t.id_tipo_documento,
            td.nombre  AS nombre_tipo_documento,
            t.numero_documento,
            t.direccion,
            t.referencia,
            t.latitud,
            t.longitud,
            t.id_pais,
            p.nombre   AS nombre_pais,
            t.id_departamento,
            d.nombre   AS nombre_departamento,
            t.id_provincia,
            pr.nombre  AS nombre_provincia,
            t.id_distrito,
            dis.nombre AS nombre_distrito,
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
            t.id_usuario,
            u.nombre   AS nombre_usuario_vinculo,
            t.id_chofer,
            ch.nombres AS nombre_chofer,
            t.estado,
            t.fecha_creacion,
            t.fecha_modificacion,
            t.id_usuario_creacion,
            uc.nombre  AS nombre_usuario_creacion,
            t.id_usuario_modificacion,
            um.nombre  AS nombre_usuario_modificacion
        FROM tra_trabajadores t
        LEFT JOIN gen_lista_opciones td ON t.id_tipo_documento = td.id
        LEFT JOIN gen_pais p            ON t.id_pais = p.id
        LEFT JOIN gen_departamento d    ON t.id_departamento = d.id
        LEFT JOIN gen_provincia pr      ON t.id_provincia = pr.id
        LEFT JOIN gen_distrito dis      ON t.id_distrito = dis.id
        LEFT JOIN gen_lista_opciones a  ON t.id_area = a.id
        LEFT JOIN gen_lista_opciones c  ON t.id_cargo = c.id
        LEFT JOIN auth_usuarios u       ON t.id_usuario = u.id
        LEFT JOIN gen_chofer ch         ON t.id_chofer = ch.id
        LEFT JOIN auth_usuarios uc      ON t.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um      ON t.id_usuario_modificacion = um.id
        WHERE t.id = p_id AND t.estado IN (0, 1)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
