CREATE OR REPLACE FUNCTION act_obtener_activo(p_id INTEGER)
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
            a.id,
            a.id_tipo,
            tp.nombre   AS nombre_tipo,
            a.descripcion,
            a.fecha_compra,
            a.importe,
            a.id_sucursal,
            s.nombre    AS nombre_sucursal,
            a.marca,
            a.modelo,
            a.numero_serie,
            a.id_trabajador_responsable,
            tr.nombres  AS nombre_trabajador_responsable,
            a.imagen_principal_ruta,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombre   AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombre   AS nombre_usuario_modificacion
        FROM act_activos a
        LEFT JOIN gen_lista_opciones tp ON a.id_tipo = tp.id
        LEFT JOIN gen_sucursal s        ON a.id_sucursal = s.id
        LEFT JOIN tra_trabajadores tr   ON a.id_trabajador_responsable = tr.id
        LEFT JOIN auth_usuarios uc      ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um      ON a.id_usuario_modificacion = um.id
        WHERE a.id = p_id AND a.estado IN (0, 1)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
