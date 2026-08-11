CREATE OR REPLACE FUNCTION bal_actualizar_ruta_pueblo(
    p_id INTEGER,
    p_fecha DATE DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_id_chofer INTEGER DEFAULT NULL,
    p_factor_lb_m3 NUMERIC DEFAULT NULL,
    p_tolerancia_m3 NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_estado_nombre VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado INTEGER;
    v_estado_nuevo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre INTO v_estado
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado IN ('CERRADA', 'CANCELADA') THEN
        RETURN json_build_object('error', 'No se puede editar una ruta cerrada o cancelada', 'registro', NULL);
    END IF;

    v_estado_nuevo := NULLIF(UPPER(TRIM(COALESCE(p_estado_nombre, ''))), '');
    IF v_estado_nuevo IS NOT NULL THEN
        IF v_estado_nuevo NOT IN ('CANCELADA') THEN
            RETURN json_build_object(
                'error',
                'Use iniciar / retorno / cerrar para cambiar de estado; solo CANCELADA vía actualizar',
                'registro',
                NULL
            );
        END IF;
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'CANCELADA' AND lo.estado = 1
        LIMIT 1;
    END IF;

    UPDATE bal_ruta_pueblo
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable),
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        factor_lb_m3 = COALESCE(NULLIF(p_factor_lb_m3, 0), factor_lb_m3),
        tolerancia_m3 = COALESCE(NULLIF(p_tolerancia_m3, 0), tolerancia_m3),
        id_estado = COALESCE(v_id_estado, id_estado),
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            ELSE NULLIF(TRIM(p_observacion), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;
