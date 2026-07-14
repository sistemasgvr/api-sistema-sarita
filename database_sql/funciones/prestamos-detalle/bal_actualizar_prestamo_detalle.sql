CREATE OR REPLACE FUNCTION bal_actualizar_prestamo_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_motivo_especifico VARCHAR DEFAULT NULL,
    p_fecha_entregado DATE DEFAULT NULL,
    p_fecha_prestamo DATE DEFAULT NULL,
    p_dias_prestamo INTEGER DEFAULT NULL,
    p_fecha_vencimiento DATE DEFAULT NULL,
    p_fecha_devolucion DATE DEFAULT NULL,
    p_serie_guia_entrega VARCHAR DEFAULT NULL,
    p_numero_guia_entrega VARCHAR DEFAULT NULL,
    p_serie_guia_devolucion VARCHAR DEFAULT NULL,
    p_numero_guia_devolucion VARCHAR DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE bal_prestamo_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_producto = COALESCE(p_id_producto, id_producto),
        motivo_especifico = COALESCE(p_motivo_especifico, motivo_especifico),
        fecha_entregado = COALESCE(p_fecha_entregado, fecha_entregado),
        fecha_prestamo = COALESCE(p_fecha_prestamo, fecha_prestamo),
        dias_prestamo = COALESCE(p_dias_prestamo, dias_prestamo),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        fecha_devolucion = COALESCE(p_fecha_devolucion, fecha_devolucion),
        serie_guia_entrega = COALESCE(p_serie_guia_entrega, serie_guia_entrega),
        numero_guia_entrega = COALESCE(p_numero_guia_entrega, numero_guia_entrega),
        serie_guia_devolucion = COALESCE(p_serie_guia_devolucion, serie_guia_devolucion),
        numero_guia_devolucion = COALESCE(p_numero_guia_devolucion, numero_guia_devolucion),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;
