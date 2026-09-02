-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.589Z
DROP FUNCTION IF EXISTS bal_obtener_prestamo_detalle(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_prestamo_detalle(p_id integer)
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
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pr.id_cliente,
            pr.id_almacen,
            pd.id_producto,
            COALESCE(pg.nombre, p.nombre) AS nombre_producto,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            eb.nombre AS nombre_estado_balon,
            pd.motivo_especifico,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.dias_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_guia_entrega,
            ge.serie AS serie_guia_entrega_gre,
            ge.numero AS numero_guia_entrega_gre,
            pd.id_guia_devolucion,
            gd.serie AS serie_guia_devolucion_gre,
            gd.numero AS numero_guia_devolucion_gre,
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
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        LEFT JOIN gre_guia_remision ge ON pd.id_guia_entrega = ge.id
        LEFT JOIN gre_guia_remision gd ON pd.id_guia_devolucion = gd.id
        LEFT JOIN auth_usuarios uc ON pd.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pd.id_usuario_modificacion = um.id
        WHERE pd.id = p_id AND pd.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
