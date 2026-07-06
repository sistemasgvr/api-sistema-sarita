CREATE OR REPLACE FUNCTION bal_obtener_tipo_balon(p_id INTEGER)
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
            tb.id,
            tb.nombre,
            tb.id_gas,
            g.nombre AS nombre_gas,
            g.codigo AS codigo_gas,
            tb.capacidad,
            tb.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            tb.peso,
            tb.estado,
            tb.fecha_creacion,
            tb.fecha_modificacion,
            tb.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            tb.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_balon b
                WHERE b.id_tipo_balon = tb.id AND b.estado = 1
            ) AS total_balones
        FROM bal_tipo_balon tb
        LEFT JOIN pro_producto g ON tb.id_gas = g.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON tb.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON tb.id_usuario_modificacion = um2.id
        WHERE tb.id = p_id AND tb.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
