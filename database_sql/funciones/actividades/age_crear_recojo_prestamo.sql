-- Function: age_crear_recojo_prestamo
-- Fase 6 (apuntes 8.b.i.4 y 8.b.i.5) — actividad de recojo a partir de un préstamo.
--
-- Los ítems salen del detalle del préstamo, no se re-teclean: un recojo es ir a
-- buscar exactamente los cilindros que se entregaron y siguen fuera.
--
-- Es idempotente por préstamo: si ya hay una actividad de recojo abierta para
-- ese préstamo devuelve la existente. Así el job programado puede correr todos
-- los días sin llenar la agenda de duplicados.
DROP FUNCTION IF EXISTS age_crear_recojo_prestamo(p_id_prestamo integer, p_fecha_programada date, p_id_trabajador_responsable integer, p_observaciones character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_prestamo(p_id_prestamo integer, p_fecha_programada date DEFAULT NULL::date, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo      RECORD;
    v_id_existente  INTEGER;
    v_id_tipo       INTEGER;
    v_id_estado     INTEGER;
    v_id_prioridad  INTEGER;
    v_id_origen     INTEGER;
    v_id_pendiente  INTEGER;
    v_id_actividad  INTEGER;
    v_items         INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.id, p.numero_prestamo, p.id_cliente, p.fecha_retorno_pactada,
           COALESCE(
               NULLIF(TRIM(cli.razon_social), ''),
               NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
               cli.numero_documento
           ) AS nombre_cliente
    INTO v_prestamo
    FROM bal_prestamo p
    LEFT JOIN cli_clientes cli ON cli.id = p.id_cliente
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF v_prestamo.id IS NULL THEN
        RETURN json_build_object('error', 'El préstamo no existe o está anulado', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoActividad' AND lo.nombre = 'RECOJO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoActividad' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_tipo IS NULL OR v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Faltan catálogos TipoActividad/EstadoActividad', 'registro', NULL);
    END IF;

    -- Ya hay un recojo abierto para este préstamo: no se duplica.
    SELECT a.id INTO v_id_existente
    FROM age_actividad a
    JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id_prestamo = p_id_prestamo
      AND a.estado = 1
      AND a.id_tipo_actividad = v_id_tipo
      AND ea.nombre = 'PENDIENTE'
    ORDER BY a.id DESC
    LIMIT 1;

    IF v_id_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('id', v_id_existente, 'creada', FALSE, 'items', 0)
        );
    END IF;

    SELECT lo.id INTO v_id_prioridad
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PrioridadActividad' AND lo.nombre = 'ALTA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_origen
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = 'PRESTAMO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada, id_tipo_actividad, id_prioridad,
        id_cliente, id_trabajador_responsable, id_estado_actividad, observaciones,
        id_prestamo, id_tipo_origen, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        format('Recojo préstamo %s', COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::TEXT)),
        format('Recojo de cilindros de %s', COALESCE(v_prestamo.nombre_cliente, 'cliente')),
        COALESCE(p_fecha_programada, v_prestamo.fecha_retorno_pactada, CURRENT_DATE),
        v_id_tipo, v_id_prioridad,
        v_prestamo.id_cliente, p_id_trabajador_responsable, v_id_estado, p_observaciones,
        p_id_prestamo, v_id_origen, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_actividad;

    -- Solo los cilindros que siguen fuera: los ya devueltos no se van a recoger.
    INSERT INTO age_actividad_item (
        id_actividad, item, id_producto, descripcion, cantidad, id_balon,
        id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
        id_usuario_creacion, id_usuario_modificacion
    )
    SELECT
        v_id_actividad,
        ROW_NUMBER() OVER (ORDER BY pd.id),
        COALESCE(pd.id_producto, b.id_producto_gas),
        COALESCE(b.codigo_balon, 'Cilindro'),
        1,
        pd.id_balon,
        pd.id,
        v_id_pendiente,
        v_id_pendiente,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM bal_prestamo_detalle pd
    LEFT JOIN bal_balon b ON b.id = pd.id_balon
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
      AND pd.id_balon IS NOT NULL;

    GET DIAGNOSTICS v_items = ROW_COUNT;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', v_items)
    );
END;
$function$;
