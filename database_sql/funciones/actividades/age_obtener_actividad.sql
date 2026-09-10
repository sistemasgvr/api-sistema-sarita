-- Function: age_obtener_actividad
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql

CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id integer)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_detalle_origen JSON := NULL;
    v_tiene_items BOOLEAN;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            um.nombre AS nombre_unidad_medida,
            i.id_balon,
            b.codigo_balon,
            b.numero_serie AS numero_serie_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            COALESCE(pgb.nombre, p.nombre) AS nombre_producto_gas,
            i.id_estado_verificacion_salida,
            evs.nombre AS estado_verificacion_salida,
            i.observacion_salida,
            i.id_estado_verificacion_llegada,
            evl.nombre AS estado_verificacion_llegada,
            i.observacion_llegada,
            i.id_estado_producto_recogido,
            epr.nombre AS estado_producto_recogido,
            i.id_doc_salida_detalle,
            i.id_venta_detalle,
            i.id_prestamo_detalle,
            i.id_alquiler_detalle
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones evs ON evs.id = i.id_estado_verificacion_salida
        LEFT JOIN gen_lista_opciones evl ON evl.id = i.id_estado_verificacion_llegada
        LEFT JOIN gen_lista_opciones epr ON epr.id = i.id_estado_producto_recogido
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    v_tiene_items := COALESCE(json_array_length(v_items), 0) > 0;

    SELECT act.id_prestamo, act.id_alquiler
    INTO v_id_prestamo, v_id_alquiler
    FROM age_actividad act
    WHERE act.id = p_id AND act.estado = 1;

    IF NOT v_tiene_items AND v_id_prestamo IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'PRESTAMO',
            'id_origen', p.id,
            'numero', p.numero_prestamo,
            'fecha_pactada', p.fecha_retorno_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        pd.id,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        COALESCE(pd.id_producto, b.id_producto_gas) AS id_producto,
                        COALESCE(pg.nombre, pgb.nombre) AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pg ON pg.id = pd.id_producto
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE pd.id_prestamo = p.id
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                      AND pd.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_prestamo = p.id AND vg.estado = 1
                ) g
            ), '[]'::JSON)
        )
        INTO v_detalle_origen
        FROM bal_prestamo p
        WHERE p.id = v_id_prestamo;
    ELSIF NOT v_tiene_items AND v_id_alquiler IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'ALQUILER',
            'id_origen', a.id,
            'numero', a.numero_alquiler,
            'fecha_pactada', a.fecha_fin_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        ad.id,
                        ad.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        b.id_producto_gas AS id_producto,
                        pgb.nombre AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_alquiler_detalle ad
                    LEFT JOIN bal_balon b ON b.id = ad.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE ad.id_alquiler = a.id
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                      AND ad.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_alquiler = a.id AND vg.estado = 1
                ) g
            ), '[]'::JSON),
            'regulador', CASE
                WHEN a.id_producto_regulador IS NOT NULL AND a.fecha_devolucion_regulador IS NULL
                THEN json_build_object(
                    'id_producto', a.id_producto_regulador,
                    'nombre_producto', COALESCE(pr.nombre, ps.nombre),
                    'codigo_producto', COALESCE(pr.codigo, ps.codigo),
                    'pendiente', TRUE
                )
                ELSE NULL
            END
        )
        INTO v_detalle_origen
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_id_alquiler;
    END IF;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_prestamo,
            bp.numero_prestamo,
            bp.fecha_retorno_pactada AS fecha_retorno_pactada_prestamo,
            act.id_alquiler,
            ba.numero_alquiler,
            ba.fecha_fin_pactada AS fecha_fin_pactada_alquiler,
            act.id_tipo_origen,
            tor.nombre AS nombre_tipo_origen,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items,
            v_detalle_origen AS detalle_origen
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN gen_lista_opciones tor ON tor.id = act.id_tipo_origen
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN bal_prestamo bp ON bp.id = act.id_prestamo
        LEFT JOIN bal_alquiler ba ON ba.id = act.id_alquiler
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON act.id_usuario_modificacion = umod.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;