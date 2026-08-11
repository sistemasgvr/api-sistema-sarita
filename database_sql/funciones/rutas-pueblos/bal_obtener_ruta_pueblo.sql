CREATE OR REPLACE FUNCTION bal_obtener_ruta_pueblo(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.id_almacen,
            a.nombre AS nombre_almacen,
            r.id_usuario_responsable,
            u.nombre AS nombre_usuario_responsable,
            r.id_chofer,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer,
            r.factor_lb_m3,
            r.tolerancia_m3,
            r.m3_reportado_ventas,
            r.m3_calculado,
            r.descuadre_m3,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.observacion,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_almacen a ON a.id = r.id_almacen
        LEFT JOIN auth_usuarios u ON u.id = r.id_usuario_responsable
        LEFT JOIN gen_chofer ch ON ch.id = r.id_chofer
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            det.id,
            det.id_ruta_pueblo,
            det.id_balon,
            b.codigo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad AS capacidad_tipo,
            tb.capacidad_lb AS capacidad_lb_tipo,
            bal_factor_lb_m3(tb.id, b.id_producto_gas) AS factor_lb_m3_tipo,
            det.sellado,
            det.lb_salida,
            det.lb_retorno,
            det.m3_delta,
            det.capacidad_restante_m3,
            det.observacion
        FROM bal_ruta_pueblo_detalle det
        INNER JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE det.id_ruta_pueblo = p_id AND det.estado = 1
    ) d;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro::JSONB || jsonb_build_object('detalles', v_detalles))::JSON
    );
END;
$function$;
