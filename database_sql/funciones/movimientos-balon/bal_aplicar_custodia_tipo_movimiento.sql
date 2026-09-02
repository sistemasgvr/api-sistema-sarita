-- Aplica el Libro (custodia viva) según TipoMovBalon. Solo movimientos sin documento.
CREATE OR REPLACE FUNCTION bal_aplicar_custodia_tipo_movimiento(
    p_id_movimiento INTEGER,
    p_revertir BOOLEAN DEFAULT FALSE,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov RECORD;
    v_tipo TEXT;
    v_codigo_estado TEXT;
    v_id_estado INTEGER;
    v_almacen INTEGER;
    v_cliente INTEGER;
    v_limpiar_almacen BOOLEAN := FALSE;
    v_contenido TEXT;
BEGIN
    SELECT
        m.id_balon,
        m.id_documento_ref,
        m.id_cliente,
        m.id_almacen_origen,
        m.id_almacen_destino,
        lo.nombre AS tipo
    INTO v_mov
    FROM bal_movimiento m
    LEFT JOIN gen_lista_opciones lo ON lo.id = m.id_tipo_movimiento
    WHERE m.id = p_id_movimiento;

    IF NOT FOUND OR v_mov.id_documento_ref IS NOT NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    v_tipo := v_mov.tipo;

    IF p_revertir THEN
        v_codigo_estado := 'EN_ALMACEN';
        v_almacen := COALESCE(v_mov.id_almacen_origen, v_mov.id_almacen_destino);
        v_cliente := NULL;
        v_limpiar_almacen := FALSE;
    ELSE
        CASE v_tipo
            WHEN 'SALIDA_PRESTAMO' THEN
                v_codigo_estado := 'PRESTADO_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_ALQUILER' THEN
                v_codigo_estado := 'ALQUILADO';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_VENTA' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'SALIDA_MANTENIMIENTO' THEN
                v_codigo_estado := 'EN_MANTENIMIENTO';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
            WHEN 'SALIDA_PLANTA_EXTERNA' THEN
                v_codigo_estado := 'EN_RECARGA_EXTERNA';
                v_limpiar_almacen := TRUE;
                v_contenido := 'VACIO';
            WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
                v_codigo_estado := 'EN_ALMACEN';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
            WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
                v_codigo_estado := 'EN_ALMACEN';
                v_almacen := COALESCE(v_mov.id_almacen_destino, v_mov.id_almacen_origen);
                v_contenido := 'LLENO';
            WHEN 'RECARGA_CLIENTE' THEN
                v_codigo_estado := 'EN_PODER_CLIENTE';
                v_cliente := v_mov.id_cliente;
                v_limpiar_almacen := TRUE;
            WHEN 'TRASLADO_LIMA' THEN
                v_codigo_estado := 'EN_RUTA_LIMA';
                v_limpiar_almacen := TRUE;
            ELSE
                RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
        END CASE;
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('ok', FALSE, 'error', format('Estado %s no configurado', v_codigo_estado));
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado,
        id_cliente_ubicacion = CASE
            WHEN v_limpiar_almacen THEN v_cliente
            WHEN v_cliente IS NOT NULL THEN v_cliente
            ELSE NULL
        END,
        id_almacen = CASE
            WHEN v_limpiar_almacen THEN NULL
            ELSE v_almacen
        END,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = v_mov.id_balon AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'skipped', FALSE);
END;
$function$;
