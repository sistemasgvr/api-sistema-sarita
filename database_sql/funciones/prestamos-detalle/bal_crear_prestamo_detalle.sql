CREATE OR REPLACE FUNCTION bal_crear_prestamo_detalle(
    p_id_prestamo INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_motivo_especifico VARCHAR DEFAULT NULL,
    p_fecha_entregado DATE DEFAULT NULL,
    p_fecha_prestamo DATE DEFAULT NULL,
    p_dias_prestamo INTEGER DEFAULT 30,
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
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_prestamo_detalle (
        id_prestamo, id_balon, id_producto, motivo_especifico,
        fecha_entregado, fecha_prestamo, dias_prestamo, fecha_vencimiento, fecha_devolucion,
        serie_guia_entrega, numero_guia_entrega, serie_guia_devolucion, numero_guia_devolucion,
        id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_prestamo, p_id_balon, p_id_producto, p_motivo_especifico,
        p_fecha_entregado, p_fecha_prestamo, COALESCE(p_dias_prestamo, 30), p_fecha_vencimiento, p_fecha_devolucion,
        p_serie_guia_entrega, p_numero_guia_entrega, p_serie_guia_devolucion, p_numero_guia_devolucion,
        p_id_estado, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_prestamo_detalle(v_id);
END;
$function$;
