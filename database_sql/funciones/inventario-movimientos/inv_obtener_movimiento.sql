-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_obtener_movimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.762Z
DROP FUNCTION IF EXISTS inv_obtener_movimiento(p_id integer);

CREATE OR REPLACE FUNCTION inv_obtener_movimiento(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.naturaleza,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            m.id_balon,
            b.numero_serie AS numero_serie_balon,
            m.cantidad,
            m.id_unidad_medida,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_cliente,
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), ''),
                cli.numero_documento
            ) AS nombre_cliente,
            m.id_documento_origen,
            m.id_tipo_documento_origen,
            tdo.nombre AS nombre_tipo_documento_origen,
            m.id_documento_detalle,
            m.id_movimiento_padre,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_estado_balon_snapshot,
            eb.nombre AS nombre_estado_balon_snapshot,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM inv_movimiento m
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
        LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        LEFT JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        LEFT JOIN gen_lista_opciones eb ON eb.id = m.id_estado_balon_snapshot
        LEFT JOIN auth_usuarios uc ON uc.id = m.id_usuario_creacion
        LEFT JOIN auth_usuarios um ON um.id = m.id_usuario_modificacion
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
