-- Obtiene ruta pueblo por id
DROP FUNCTION IF EXISTS public.bal_obtener_ruta_pueblo (p_id integer);

CREATE OR REPLACE FUNCTION public.bal_obtener_ruta_pueblo (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_detalles_productos JSON;
    v_m3_exacto NUMERIC;
    v_m3_registrado NUMERIC;
    v_ajuste_m3 NUMERIC;
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
            r.control_gas_manual,
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
            um.nombre AS unidad_capacidad_tipo,
            CASE WHEN det.m3_salida IS NULL THEN bal_factor_ruta_balon(b.id, FALSE) ELSE NULL END AS factor_lb_m3_tipo,
            det.sellado,
            det.lb_salida,
            det.m3_salida,
            det.m3_retorno,
            det.id_producto_gas,
            det.lb_retorno,
            det.m3_delta,
            det.observacion
        FROM bal_ruta_pueblo_detalle det
        INNER JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
        WHERE det.id_ruta_pueblo = p_id AND det.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(dp) ORDER BY dp.id), '[]'::JSON)
    INTO v_detalles_productos
    FROM (
        SELECT
            detp.id,
            detp.id_ruta_pueblo,
            detp.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            detp.cantidad,
            detp.cantidad_retorno,
            detp.observacion
        FROM bal_ruta_pueblo_detalle_producto detp
        INNER JOIN pro_producto p ON p.id = detp.id_producto
        WHERE detp.id_ruta_pueblo = p_id AND detp.estado = 1
    ) dp;

    -- El detalle conserva la conversión original. La nota se deriva de los
    -- valores guardados y no se pierde al editar la observación del usuario.
    SELECT COALESCE(SUM(d.m3_delta), 0) INTO v_m3_exacto
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL;
    v_m3_registrado := (v_registro->>'m3_calculado')::NUMERIC;
    v_ajuste_m3 := v_m3_registrado - v_m3_exacto;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro::JSONB
            || jsonb_build_object(
                'm3_calculado_exacto', v_m3_exacto,
                'ajuste_truncamiento_m3', v_ajuste_m3,
                'observacion_truncamiento', CASE WHEN v_ajuste_m3 <> 0 THEN
                    format('Consumo calculado: %s m³. Consumo registrado: %s m³. Ajuste por truncamiento: %s m³.',
                        v_m3_exacto, v_m3_registrado, v_ajuste_m3)
                    ELSE NULL END
            )
            || jsonb_build_object('detalles', v_detalles)
            || jsonb_build_object('detalles_productos', v_detalles_productos)
        )::JSON
    );
END;
$function$;
