CREATE OR REPLACE FUNCTION bal_obtener_recojo(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSONB;
    v_detalles JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT to_jsonb(t)
    INTO v_registro
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            dir.latitud,
            dir.longitud,
            dir.direccion,
            r.id_prestamo,
            pr.numero_prestamo,
            r.id_alquiler,
            al.numero_alquiler,
            CASE
                WHEN r.id_prestamo IS NOT NULL AND r.id_alquiler IS NOT NULL THEN 'MIXTO'
                WHEN r.id_alquiler IS NOT NULL THEN 'ALQUILER'
                ELSE 'PRESTAMO'
            END AS tipo_origen,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            er.descripcion AS descripcion_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            mf.descripcion AS descripcion_motivo_fallo,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            r.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN bal_alquiler al ON al.id = r.id_alquiler
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        LEFT JOIN auth_usuarios uc ON uc.id = r.id_usuario_creacion
        LEFT JOIN auth_usuarios um ON um.id = r.id_usuario_modificacion
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud, cd.direccion
            FROM cli_direcciones cd
            WHERE cd.id_cliente = r.id_cliente
              AND cd.es_principal = TRUE
              AND cd.estado = 1
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            rd.id,
            rd.id_recojo,
            rd.id_prestamo_detalle,
            rd.id_alquiler_detalle,
            CASE
                WHEN rd.id_alquiler_detalle IS NOT NULL THEN 'ALQUILER'
                ELSE 'PRESTAMO'
            END AS origen,
            COALESCE(pd.id_prestamo, ad.id_alquiler) AS id_origen,
            COALESCE(pr.numero_prestamo, al.numero_alquiler) AS numero_origen,
            COALESCE(pd.id_balon, ad.id_balon) AS id_balon,
            b.codigo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            tb.capacidad AS capacidad,
            COALESCE(um_prod.nombre, um_tipo.nombre) AS nombre_unidad_medida,
            COALESCE(um_prod.descripcion, um_tipo.descripcion) AS descripcion_unidad_medida,
            COALESCE(pd.fecha_vencimiento, al.fecha_fin_pactada) AS fecha_vencimiento,
            COALESCE(pd.fecha_devolucion, ad.fecha_devolucion) AS fecha_devolucion,
            rd.id_resultado,
            res.nombre AS nombre_resultado,
            res.descripcion AS descripcion_resultado,
            rd.id_estado_contenido,
            ec.nombre AS nombre_estado_contenido,
            rd.cantidad_restante,
            rd.nueva_fecha_retorno,
            rd.id_almacen_destino,
            a.nombre AS nombre_almacen_destino,
            rd.observacion,
            rd.estado
        FROM bal_recojo_detalle rd
        LEFT JOIN bal_prestamo_detalle pd
            ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
        LEFT JOIN bal_prestamo pr ON pr.id = pd.id_prestamo
        LEFT JOIN bal_alquiler_detalle ad
            ON ad.id = rd.id_alquiler_detalle AND ad.estado = 1
        LEFT JOIN bal_alquiler al ON al.id = ad.id_alquiler
        LEFT JOIN bal_balon b ON b.id = COALESCE(pd.id_balon, ad.id_balon)
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pg ON pg.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones um_prod ON um_prod.id = pg.id_unidad_medida
        LEFT JOIN gen_lista_opciones um_tipo ON um_tipo.id = tb.id_unidad_medida
        LEFT JOIN gen_lista_opciones res ON res.id = rd.id_resultado
        LEFT JOIN gen_lista_opciones ec ON ec.id = rd.id_estado_contenido
        LEFT JOIN gen_almacen a ON a.id = rd.id_almacen_destino
        WHERE rd.id_recojo = p_id AND rd.estado = 1
    ) d;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro || jsonb_build_object('detalles', COALESCE(v_detalles::JSONB, '[]'::JSONB)))::JSON
    );
END;
$function$;
