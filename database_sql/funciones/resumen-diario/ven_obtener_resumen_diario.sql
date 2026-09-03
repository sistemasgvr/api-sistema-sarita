-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_obtener_resumen_diario
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_obtener_resumen_diario(p_id integer);

CREATE OR REPLACE FUNCTION ven_obtener_resumen_diario(p_id integer)
 RETURNS json
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
            r.correlativo,
            r.identificador,
            r.ticket_sunat,
            r.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            r.hash_documento,
            r.cdr_respuesta,
            r.moneda,
            r.cantidad_docs,
            r.total_importe,
            r.total_igv,
            r.total_valor_venta,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM ven_resumen_diario r
        LEFT JOIN gen_lista_opciones es ON r.id_estado_sunat = es.id
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL, 'detalles', '[]'::JSON);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_resumen,
            d.id_comprobante,
            d.item,
            c.serie,
            c.numero,
            tc.descripcion AS codigo_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            c.fecha AS fecha_comprobante,
            c.total_importe,
            c.igv,
            c.valor_venta,
            es.nombre AS nombre_estado_sunat,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente
        FROM ven_resumen_diario_detalle d
        LEFT JOIN ven_comprobante c ON d.id_comprobante = c.id
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        WHERE d.id_resumen = p_id AND d.estado = 1
    ) d;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles
    );
END;
$function$;
