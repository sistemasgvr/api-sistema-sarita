CREATE OR REPLACE FUNCTION bal_obtener_prestamo_detalle(p_id INTEGER)
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
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pd.id_producto,
            p.nombre AS nombre_producto,
            pd.motivo_especifico,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.dias_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.serie_guia_entrega,
            pd.numero_guia_entrega,
            pd.serie_guia_devolucion,
            pd.numero_guia_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.observacion,
            pd.estado,
            pd.fecha_creacion,
            pd.fecha_modificacion,
            pd.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            pd.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        LEFT JOIN auth_usuarios uc ON pd.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pd.id_usuario_modificacion = um.id
        WHERE pd.id = p_id AND pd.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
