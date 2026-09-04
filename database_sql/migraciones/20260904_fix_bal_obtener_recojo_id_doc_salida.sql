-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
--
-- Bug preexistente confirmado en vivo (encontrado al probar Fase 4 — préstamo con
-- garantía de balón + fecha de retorno pactada, que dispara el auto-recojo de
-- ven_aplicar_efectos_pos → bal_crear_recojo → bal_obtener_recojo):
-- bal_obtener_recojo referenciaba bal_recojo.id_recarga_planta, columna que ya no
-- existe — Fase 2 la renombró a id_doc_salida al migrar de bal_recarga_planta a
-- doc_salida (bal_crear_recojo, en el mismo archivo/módulo, ya usa id_doc_salida
-- correctamente; solo bal_obtener_recojo se quedó con el nombre viejo). Cualquier
-- creación de recojo (incluyendo el auto-recojo del POS) fallaba con
-- 'column r2.id_recarga_planta does not exist' — error real reportado por el usuario:
-- POST /comprobantes failed: column r2.id_recarga_planta does not exist | code=P0001.

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.948Z
DROP FUNCTION IF EXISTS bal_obtener_recojo(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_recojo(p_id integer)
 RETURNS json
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
            COALESCE(al.id_producto_regulador, al.id_producto_stock) AS id_producto_alquiler,
            COALESCE(pr_alq.codigo, ps_alq.codigo) AS codigo_producto_alquiler,
            COALESCE(pr_alq.nombre, ps_alq.nombre) AS nombre_producto_alquiler,
            CASE
                WHEN r.id_alquiler IS NOT NULL
                     AND COALESCE(al.id_producto_regulador, al.id_producto_stock) IS NOT NULL
                THEN TRUE
                ELSE FALSE
            END AS tiene_regulador,
            CASE
                WHEN r.id_alquiler IS NOT NULL
                     AND COALESCE(al.id_producto_regulador, al.id_producto_stock) IS NOT NULL
                     AND NOT EXISTS (
                         SELECT 1
                         FROM bal_recojo_detalle rd0
                         WHERE rd0.id_recojo = r.id AND rd0.estado = 1
                     )
                THEN TRUE
                ELSE FALSE
            END AS es_solo_regulador,
            r.id_resultado_regulador,
            rr.nombre AS nombre_resultado_regulador,
            r.id_condicion_regulador,
            cr.nombre AS nombre_condicion_regulador,
            cr.descripcion AS descripcion_condicion_regulador,
            r.nueva_fecha_retorno_regulador,
            r.observacion_regulador,
            CASE
                WHEN r.id_doc_salida IS NOT NULL THEN 'RECARGAR_PLANTA'
                WHEN r.id_prestamo IS NOT NULL AND r.id_alquiler IS NOT NULL THEN 'MIXTO'
                WHEN r.id_alquiler IS NOT NULL THEN 'ALQUILER'
                ELSE 'PRESTAMO'
            END AS tipo_origen,
            r.id_doc_salida,
            rp.numero AS numero_recarga_planta,
            r.id_compra,
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
        LEFT JOIN doc_salida rp ON rp.id = r.id_doc_salida
        LEFT JOIN pro_producto pr_alq ON pr_alq.id = al.id_producto_regulador
        LEFT JOIN pro_producto ps_alq ON ps_alq.id = al.id_producto_stock
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        LEFT JOIN gen_lista_opciones rr ON rr.id = r.id_resultado_regulador
        LEFT JOIN gen_lista_opciones cr ON cr.id = r.id_condicion_regulador
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
            rd.id_balon,
            CASE
                WHEN rd.id_balon IS NOT NULL THEN 'RECARGAR_PLANTA'
                WHEN rd.id_alquiler_detalle IS NOT NULL THEN 'ALQUILER'
                ELSE 'PRESTAMO'
            END AS origen,
            COALESCE(pd.id_prestamo, ad.id_alquiler, rp.id) AS id_origen,
            COALESCE(pr.numero_prestamo, al.numero_alquiler, rp.numero) AS numero_origen,
            COALESCE(pd.id_balon, ad.id_balon, rd.id_balon) AS id_balon,
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
        LEFT JOIN doc_salida rp
            ON rp.id = (SELECT r2.id_doc_salida FROM bal_recojo r2 WHERE r2.id = p_id)
        LEFT JOIN bal_balon b ON b.id = COALESCE(pd.id_balon, ad.id_balon, rd.id_balon)
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pg ON pg.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones um_prod ON um_prod.id = pg.id_unidad_medida
        LEFT JOIN gen_lista_opciones um_tipo ON um_tipo.id = tb.id_unidad_medida
        LEFT JOIN gen_lista_opciones res ON res.id = rd.id_resultado
        LEFT JOIN gen_almacen a ON a.id = rd.id_almacen_destino
        WHERE rd.id_recojo = p_id AND rd.estado = 1
    ) d;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro || jsonb_build_object('detalles', COALESCE(v_detalles::JSONB, '[]'::JSONB)))::JSON
    );
END;
$function$;
