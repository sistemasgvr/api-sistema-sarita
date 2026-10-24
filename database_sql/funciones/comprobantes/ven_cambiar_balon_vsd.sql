CREATE OR REPLACE FUNCTION public.ven_cambiar_balon_vsd(
    p_id integer, p_datos jsonb, p_id_usuario integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_venta ven_comprobante%ROWTYPE;
    v_old bal_balon%ROWTYPE;
    v_new bal_balon%ROWTYPE;
    v_pd bal_prestamo_detalle%ROWTYPE;
    v_anterior jsonb;
    v_result json;
    v_existente ven_vsd_operacion%ROWTYPE;
    v_id bigint;
    v_original integer;
    v_old_id integer := (p_datos->>'idBalonActual')::integer;
    v_new_id integer := (p_datos->>'idBalonNuevo')::integer;
    v_almacen integer := (p_datos->>'idAlmacen')::integer;
    v_devuelto numeric := (p_datos->>'cantidadGasDevuelta')::numeric;
    v_salida numeric := (p_datos->>'cantidadGasSalida')::numeric;
    v_condicion text := p_datos->>'condicionDevolucion';
    v_motivo text := btrim(p_datos->>'motivo');
    v_solicitud uuid := (p_datos->>'solicitud')::uuid;
    v_tipo text;
    v_estado text;
    v_producto integer;
    v_prestamo_nuevo integer;
    v_capacidad numeric;
    v_limite numeric;
    v_estado_dest integer;
    v_reserva boolean := p_datos->>'tipoOperacion' = 'CORRECCION_RESERVA';
BEGIN
    SET TIME ZONE 'America/Lima';
    -- A retried successful operation may be read even if emission happened later;
    -- the helper is called below only when this would be a NEW mutation.
    SELECT * INTO v_venta FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La venta no existe o está anulada'; END IF;
    -- Serialize retries on the sale, and reject accidental reuse for another payload.
    SELECT * INTO v_existente FROM ven_vsd_operacion WHERE solicitud = v_solicitud;
    IF FOUND THEN
        IF v_existente.id_comprobante <> p_id OR (v_existente.datos - 'idBalonOriginal') <> p_datos OR v_existente.id_usuario <> p_id_usuario THEN
            RAISE EXCEPTION 'La solicitud ya fue utilizada para otra operación';
        END IF;
        RETURN json_build_object('registro', jsonb_build_object('id', v_existente.id, 'repetida', true));
    END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id = v_venta.id_tipo_comprobante;
    IF v_tipo NOT IN ('VSD','NV','01','03') THEN RAISE EXCEPTION 'Seleccione una venta sin documento, factura o boleta'; END IF;
    PERFORM ven_validar_edicion_pre_emision(p_id);
    IF v_solicitud IS NULL OR p_id_usuario IS NULL OR COALESCE(length(v_motivo), 0) < 5 OR length(v_motivo) > 500 THEN
        RAISE EXCEPTION 'Solicitud, usuario y motivo de al menos 5 caracteres son obligatorios';
    END IF;
    IF COALESCE(p_datos->>'tipoOperacion','') NOT IN ('CAMBIO','CORRECCION_RESERVA') THEN RAISE EXCEPTION 'Seleccione corrección de reserva o cambio físico'; END IF;
    IF p_datos->>'versionEsperada' IS DISTINCT FROM (SELECT xmin::text FROM ven_comprobante WHERE id = p_id) THEN
        RAISE EXCEPTION 'La venta cambió. Recargue y revise antes de confirmar';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'La venta ya tiene un documento derivado. Gestione el cambio desde el documento vigente';
    END IF;
    IF EXISTS (SELECT 1 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE (d.id_venta = p_id OR EXISTS (SELECT 1 FROM doc_salida_referencia r WHERE r.id_doc_salida=d.id AND r.id_comprobante=p_id AND r.estado=1))
          AND d.estado = 1 AND ec.nombre <> 'ANULADA'
          AND (v_reserva OR NOT EXISTS (SELECT 1 FROM age_actividad a
            JOIN gen_lista_opciones ta ON ta.id=a.id_tipo_actividad
            JOIN gen_lista_opciones ea ON ea.id=a.id_estado_actividad
            WHERE a.id_doc_salida=d.id AND a.estado=1 AND ta.nombre='REPARTO' AND ea.nombre='REALIZADA'))) THEN
        RAISE EXCEPTION 'Hay una orden de salida vigente. Finalice o cancele el despacho antes del cambio';
    END IF;
    IF v_old_id IS NULL OR v_new_id IS NULL OR v_old_id = v_new_id OR v_almacen IS NULL
        OR v_devuelto IS NULL OR v_salida IS NULL OR v_devuelto < 0 OR v_salida < 0
        OR v_condicion IS NULL OR v_condicion NOT IN ('DISPONIBLE','EN_MANTENIMIENTO') THEN
        RAISE EXCEPTION 'Indique dos balones distintos, almacén, cantidades no negativas y condición de devolución';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_almacen AND estado = 1) THEN RAISE EXCEPTION 'El almacén está inactivo o no existe'; END IF;
    -- Same lock order for simultaneous exchanges involving the same cylinders.
    PERFORM id FROM bal_balon WHERE id IN (v_old_id, v_new_id) ORDER BY id FOR UPDATE;
    SELECT * INTO v_old FROM bal_balon WHERE id = v_old_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón devuelto no existe o está inactivo'; END IF;
    SELECT * INTO v_new FROM bal_balon WHERE id = v_new_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón de reemplazo no existe o está inactivo'; END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id = v_old.id_estado_balon;
    IF (v_reserva AND (v_estado IS DISTINCT FROM 'PENDIENTE_ENVIO' OR v_old.id_almacen IS DISTINCT FROM v_venta.id_almacen
            OR v_almacen IS DISTINCT FROM v_venta.id_almacen OR v_old.id_cliente_ubicacion IS NOT NULL))
       OR (NOT v_reserva AND (v_estado NOT IN ('EN_PODER_CLIENTE','PRESTADO_CLIENTE') OR v_old.id_cliente_ubicacion IS DISTINCT FROM v_venta.id_cliente)) THEN
        RAISE EXCEPTION 'El balón devuelto ya no está en poder del cliente de esta venta';
    END IF;
    IF EXISTS (SELECT 1 FROM age_actividad_item i JOIN age_actividad a ON a.id=i.id_actividad
        JOIN gen_lista_opciones ea ON ea.id=a.id_estado_actividad JOIN gen_lista_opciones ta ON ta.id=a.id_tipo_actividad
        WHERE i.id_balon IN (v_old_id,v_new_id) AND i.estado=1 AND a.estado=1 AND ea.nombre NOT IN ('REALIZADA','CANCELADA')
          AND NOT (i.id_balon=v_old_id AND ea.nombre='PENDIENTE' AND ta.nombre='RECOJO'
            AND i.id_prestamo_detalle IN (SELECT pd.id FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id=pd.id_prestamo
                 WHERE pr.id_comprobante_venta=p_id AND pr.estado=1 AND pd.estado=1 AND pd.fecha_devolucion IS NULL AND pd.rol='ENTREGADO'))) THEN
        RAISE EXCEPTION 'Un balón tiene una actividad pendiente o en ruta incompatible con el cambio';
    END IF;
    -- Resolve the original cylinder without rewriting the historical sale detail.
    SELECT (datos->>'idBalonOriginal')::integer INTO v_original FROM ven_vsd_operacion
        WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON'
          AND (datos->>'idBalonNuevo')::integer = v_old_id ORDER BY id DESC LIMIT 1;
    v_original := COALESCE(v_original, v_old_id);
    IF NOT EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante = p_id AND estado = 1 AND id_balon IN (v_original,v_old_id))
       AND NOT EXISTS (SELECT 1 FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id = pd.id_prestamo
          WHERE pr.id_comprobante_venta = p_id AND pr.estado = 1 AND pd.estado = 1 AND pd.id_balon = v_old_id
            AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO') THEN
        RAISE EXCEPTION 'El balón no pertenece a esta venta o ya fue devuelto';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON'
        AND (datos->>'idBalonActual')::integer = v_old_id
        AND id > COALESCE((SELECT max(id) FROM ven_vsd_operacion WHERE id_comprobante = p_id
             AND tipo = 'CAMBIO_BALON' AND (datos->>'idBalonNuevo')::integer = v_old_id), 0)) THEN
        RAISE EXCEPTION 'Este balón ya fue sustituido; recargue la venta';
    END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id = v_new.id_estado_balon;
    IF v_estado IS DISTINCT FROM 'DISPONIBLE' OR v_new.id_almacen IS DISTINCT FROM v_almacen OR v_new.id_cliente_ubicacion IS NOT NULL THEN
        RAISE EXCEPTION 'El balón de reemplazo ya no está disponible en el almacén seleccionado';
    END IF;
    IF v_new.fecha_proxima_prueba_hidrostatica IS NULL OR v_new.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN
        RAISE EXCEPTION 'El balón de reemplazo no tiene una prueba hidrostática vigente';
    END IF;
    IF EXISTS (SELECT 1 FROM bal_baja_balon WHERE id_balon=v_new_id AND estado=1 AND estado_aprobacion IN ('PENDIENTE','APROBADA'))
        OR EXISTS (SELECT 1 FROM bal_mantenimiento m WHERE m.id_balon=v_new_id AND m.estado=1 AND m.fecha_salida IS NULL) THEN
        RAISE EXCEPTION 'El balón de reemplazo tiene una baja o mantenimiento pendiente';
    END IF;
    IF v_condicion='DISPONIBLE' AND EXISTS (SELECT 1 FROM bal_baja_balon WHERE id_balon=v_old_id AND estado=1 AND estado_aprobacion IN ('PENDIENTE','APROBADA')) THEN
        RAISE EXCEPTION 'El balón devuelto tiene una solicitud de baja; no puede quedar disponible';
    END IF;
    IF v_new.id_tipo_balon IS DISTINCT FROM v_old.id_tipo_balon
       OR v_new.id_producto_gas IS DISTINCT FROM v_old.id_producto_gas
       OR v_new.id_propietario IS DISTINCT FROM v_old.id_propietario
       OR v_new.id_cliente_propietario IS DISTINCT FROM v_old.id_cliente_propietario THEN
        RAISE EXCEPTION 'El reemplazo debe tener el mismo gas, tipo y propietario. Un cambio comercial requiere devolución y una nueva venta';
    END IF;
    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
        WHERE pd.id_balon = v_new_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL) THEN
        RAISE EXCEPTION 'El balón de reemplazo ya tiene un préstamo activo';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante_detalle d JOIN ven_comprobante c ON c.id = d.id_comprobante AND c.estado = 1
        WHERE d.id_balon = v_new_id AND d.estado = 1
          AND NOT EXISTS (SELECT 1 FROM ven_vsd_operacion o WHERE o.id_comprobante = c.id AND o.tipo = 'CAMBIO_BALON'
            AND (o.datos->>'idBalonActual')::integer = v_new_id)) THEN
        RAISE EXCEPTION 'El reemplazo está vinculado a otra línea o venta; revise su disponibilidad';
    END IF;
    v_producto := v_old.id_producto_gas;
    PERFORM id FROM pro_producto WHERE id=v_producto FOR SHARE;
    v_capacidad := bal_capacidad_balon_en_unidad_gas(v_old_id);
    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = v_producto AND estado = 1 AND es_gas) THEN
        RAISE EXCEPTION 'El gas está inactivo o no existe';
    END IF;
    -- The maximum is what THIS sale delivered, expressed in the gas stock unit.
    v_limite := ven_cantidad_gas_balon_vsd(p_id,v_old_id,v_original);
    IF v_reserva AND (v_salida <> 0 OR v_devuelto <> 0 OR v_condicion <> 'DISPONIBLE') THEN
        RAISE EXCEPTION 'Corregir una reserva no mueve gas y devuelve el balón anterior a disponible';
    END IF;
    IF NOT v_reserva AND (COALESCE(v_capacidad, 0) <= 0 OR COALESCE(v_limite, 0) <= 0
        OR v_salida <> LEAST(v_capacidad, v_limite) OR v_devuelto > v_salida) THEN
        RAISE EXCEPTION 'La cantidad de salida debe coincidir con lo vendido y la capacidad del balón; el remanente no puede superarla';
    END IF;
    SELECT pd.* INTO v_pd FROM bal_prestamo_detalle pd
        JOIN LATERAL (SELECT id FROM bal_prestamo pr WHERE pr.id = pd.id_prestamo AND pr.id_comprobante_venta = p_id AND pr.estado = 1) pr ON true
        WHERE pd.id_balon = v_old_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO'
        FOR UPDATE OF pd;
    IF v_old.id_estado_balon = (SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre='PRESTADO_CLIENTE' LIMIT 1) AND v_pd.id IS NULL THEN
        RAISE EXCEPTION 'El préstamo del balón no pertenece a esta venta';
    END IF;
    IF v_reserva AND v_pd.id IS NOT NULL THEN RAISE EXCEPTION 'La reserva ya tiene préstamo; utilice su flujo de devolución'; END IF;
    SELECT lo.id INTO v_estado_dest FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre=v_condicion AND lo.estado=1 LIMIT 1;
    IF v_estado_dest IS NULL THEN RAISE EXCEPTION 'La condición de devolución no está configurada'; END IF;
    IF NOT v_reserva AND v_condicion='DISPONIBLE' AND (v_old.fecha_proxima_prueba_hidrostatica IS NULL OR v_old.fecha_proxima_prueba_hidrostatica<CURRENT_DATE) THEN
        RAISE EXCEPTION 'El balón devuelto no tiene PH vigente; regístrelo para mantenimiento';
    END IF;
    v_anterior := jsonb_build_object('venta', to_jsonb(v_venta), 'balonActual', to_jsonb(v_old), 'balonNuevo', to_jsonb(v_new), 'prestamoDetalle', to_jsonb(v_pd),
        'detallesVenta',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM ven_comprobante_detalle d WHERE id_comprobante=p_id AND estado=1),
        'garantias',(SELECT jsonb_agg(to_jsonb(g) ORDER BY g.id) FROM ven_garantia g WHERE id_prestamo_detalle=v_pd.id AND estado=1),
        'actividades',(SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) FROM age_actividad_item i WHERE id_prestamo_detalle=v_pd.id AND estado=1));
    INSERT INTO ven_vsd_operacion(id_comprobante, tipo, solicitud, motivo, datos, anterior, posterior, id_usuario)
        VALUES (p_id, 'CAMBIO_BALON', v_solicitud, v_motivo, p_datos, v_anterior, '{}'::jsonb, p_id_usuario) RETURNING id INTO v_id;
    v_result := inv_registrar_movimiento(p_naturaleza=>'BALON', p_codigo_tipo_movimiento=>'ENTRADA_DEVOLUCION',
        p_id_balon=>v_old_id, p_id_almacen_destino=>v_almacen, p_id_cliente=>v_venta.id_cliente,
        p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
        p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
    PERFORM ven_raise_si_error(v_result);
    -- Only recover gas actually measured and usable. Damaged returns must have zero usable gas.
    IF v_condicion = 'EN_MANTENIMIENTO' AND v_devuelto <> 0 THEN RAISE EXCEPTION 'Un balón para mantenimiento no puede reponer gas utilizable'; END IF;
    IF v_devuelto > 0 THEN
        v_result := inv_registrar_movimiento(p_naturaleza=>'PRODUCTO', p_codigo_tipo_movimiento=>'INGRESO',
            p_id_producto=>v_producto, p_cantidad=>v_devuelto, p_id_almacen_origen=>v_almacen,
            p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
            p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END IF;
    -- Unified movement locks stock and rejects shortage AFTER considering usable returned gas.
    v_result := inv_registrar_movimiento(p_naturaleza=>'BALON',
        p_codigo_tipo_movimiento=>CASE WHEN v_pd.id IS NULL THEN 'SALIDA_VENTA' ELSE 'SALIDA_PRESTAMO' END,
        p_id_balon=>v_new_id, p_id_producto=>v_producto, p_cantidad=>v_salida,
        p_id_almacen_origen=>v_almacen, p_id_cliente=>v_venta.id_cliente,
        p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
        p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
    PERFORM ven_raise_si_error(v_result);
    UPDATE bal_balon SET id_estado_balon=v_estado_dest, id_usuario_modificacion=p_id_usuario, fecha_modificacion=now() WHERE id=v_old_id;
    IF v_reserva THEN
        UPDATE bal_balon SET id_estado_balon=v_old.id_estado_balon,id_almacen=v_almacen,id_cliente_ubicacion=NULL,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now() WHERE id=v_new_id;
        -- Dispatch and counter delivery read the current sale detail. Its old value is in the audit snapshot.
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF NOT v_reserva AND v_tipo IN ('01','03') THEN
        -- Before issue, the invoice must print the cylinder now being delivered.
        -- Original selections remain in the operation snapshot.
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF v_pd.id IS NOT NULL THEN
        -- Retain the original contract, dates and guarantees; keep the returned detail as history.
        UPDATE bal_prestamo_detalle SET fecha_devolucion=CURRENT_DATE,
            id_estado=(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoPrestamoDetalle' AND lo.nombre='DEVUELTO' LIMIT 1),
            id_usuario_modificacion=p_id_usuario, fecha_modificacion=now() WHERE id=v_pd.id;
        INSERT INTO bal_prestamo_detalle(id_prestamo,id_balon,id_producto,motivo_especifico,fecha_entregado,fecha_prestamo,dias_prestamo,fecha_vencimiento,id_estado,observacion,rol,id_usuario_creacion,id_usuario_modificacion)
        VALUES (v_pd.id_prestamo,v_new_id,v_producto,v_pd.motivo_especifico,CURRENT_DATE,v_pd.fecha_prestamo,v_pd.dias_prestamo,v_pd.fecha_vencimiento,v_pd.id_estado,v_motivo,'ENTREGADO',p_id_usuario,p_id_usuario)
        RETURNING id INTO v_prestamo_nuevo;
        UPDATE ven_garantia SET id_prestamo_detalle=v_prestamo_nuevo,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_prestamo_detalle=v_pd.id AND estado=1;
        UPDATE age_actividad_item i SET id_balon=v_new_id,id_prestamo_detalle=v_prestamo_nuevo,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            FROM age_actividad a, gen_lista_opciones ea, gen_lista_opciones ta
            WHERE i.id_actividad=a.id AND a.id_estado_actividad=ea.id AND a.id_tipo_actividad=ta.id
              AND i.id_prestamo_detalle=v_pd.id AND i.estado=1 AND a.estado=1 AND ea.nombre='PENDIENTE' AND ta.nombre='RECOJO';
    END IF;
    UPDATE ven_vsd_operacion SET datos=datos || jsonb_build_object('idBalonOriginal',v_original),
        posterior=jsonb_build_object('balonDevuelto',(SELECT to_jsonb(b) FROM bal_balon b WHERE id=v_old_id),
             'balonEntregado',(SELECT to_jsonb(b) FROM bal_balon b WHERE id=v_new_id), 'idPrestamoDetalleNuevo',v_prestamo_nuevo)
        WHERE id=v_id;
    UPDATE ven_comprobante SET fecha_modificacion=now(),id_usuario_modificacion=p_id_usuario WHERE id=p_id;
    RETURN json_build_object('registro', jsonb_build_object('id',v_id,'repetida',false));
END;
$function$;
