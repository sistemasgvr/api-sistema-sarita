-- Comprobantes: corrección del detalle antes de emitir (agregar ítems, cambiar cantidades, reemplazar balones) y ajuste de caja.
-- 1) ven_cambiar_balon_vsd: nuevo tipo CORRECCION_REGISTRO (cilindro que ya figura con el cliente: venta de
--    mostrador / préstamo, registrado con el código equivocado). En las correcciones (reserva y registro) un
--    balón con préstamo ya no se rechaza: se busca su préstamo (por la venta o, si no quedó ligado, el vigente
--    del cliente), se da de baja esa línea y se genera una nueva con el balón correcto, mismas fechas y
--    condiciones; garantía y recojo pendiente pasan a la nueva. El registrado vuelve a DISPONIBLE. Sin mover gas.
--    En las correcciones el reemplazo solo debe ser del mismo tipo de cilindro (gas y propietario pueden diferir).
-- 2) ven_actualizar_comprobante (nueva firma con p_cambios_balon jsonb; se elimina la anterior):
--   * Ventas con balones/préstamos/recargas/órdenes: solo las líneas vinculadas (balón, gas, alquiler,
--     garantía) conservan producto y cantidad; las demás se pueden agregar, quitar o cambiar de cantidad.
--   * Ítems nuevos toman un número libre (antes podían chocar con uno existente y fallar como duplicado).
--   * Reemplazo de balones del detalle en el mismo guardado: CORRECCION_RESERVA si el cilindro está
--     PENDIENTE_ENVIO, CORRECCION_REGISTRO si ya está con el cliente. El nuevo debe estar libre y sin despacho.
--   * Caja: si cambia el total, la fecha o la sucursal se valida que la caja del día no esté cerrada;
--     el cobro de un solo medio se ajusta al nuevo total y con varios medios se exige el reparto.
-- Respaldar la base antes de aplicarlo; publicar ANTES que la API (que envía el parámetro nuevo) y el admin.
-- PENDIENTE DE PUBLICAR: no ejecutar sin revisión. Idempotente (DROP FUNCTION IF EXISTS / CREATE OR REPLACE).
BEGIN;

DROP FUNCTION IF EXISTS public.ven_cambiar_balon_vsd (p_id integer, p_datos jsonb, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.ven_cambiar_balon_vsd (p_id integer, p_datos jsonb, p_id_usuario integer) RETURNS json LANGUAGE plpgsql AS $function$
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
    -- Corrección de registro: el cilindro ya figura con el cliente (venta de mostrador,
    -- préstamo) pero se registró el código equivocado. El registrado vuelve a DISPONIBLE
    -- y el correcto toma su lugar (estado, cliente y préstamo), sin mover gas.
    v_registro boolean := p_datos->>'tipoOperacion' = 'CORRECCION_REGISTRO';
BEGIN
    SET TIME ZONE 'America/Lima';
    SELECT * INTO v_venta FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La venta no existe o está anulada'; END IF;
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
    IF COALESCE(p_datos->>'tipoOperacion','') NOT IN ('CAMBIO','CORRECCION_RESERVA','CORRECCION_REGISTRO') THEN RAISE EXCEPTION 'Seleccione corrección de reserva, corrección de registro o cambio físico'; END IF;
    IF p_datos->>'versionEsperada' IS DISTINCT FROM (SELECT xmin::text FROM ven_comprobante WHERE id = p_id) THEN
        RAISE EXCEPTION 'La venta cambió. Recargue y revise antes de confirmar';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'La venta ya tiene un documento derivado. Gestione el cambio desde el documento vigente';
    END IF;
    IF EXISTS (SELECT 1 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE (d.id_venta = p_id OR EXISTS (SELECT 1 FROM doc_salida_referencia r WHERE r.id_doc_salida=d.id AND r.id_comprobante=p_id AND r.estado=1))
          AND d.estado = 1 AND ec.nombre <> 'ANULADA'
          AND (v_reserva OR v_registro OR NOT EXISTS (SELECT 1 FROM age_actividad a
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
    PERFORM id FROM bal_balon WHERE id IN (v_old_id, v_new_id) ORDER BY id FOR UPDATE;
    SELECT * INTO v_old FROM bal_balon WHERE id = v_old_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón devuelto no existe o está inactivo'; END IF;
    SELECT * INTO v_new FROM bal_balon WHERE id = v_new_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón de reemplazo no existe o está inactivo'; END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id = v_old.id_estado_balon;
    IF (v_reserva AND (v_estado IS DISTINCT FROM 'PENDIENTE_ENVIO' OR v_old.id_almacen IS DISTINCT FROM v_venta.id_almacen
            OR v_almacen IS DISTINCT FROM v_venta.id_almacen OR v_old.id_cliente_ubicacion IS NOT NULL))
       OR (v_registro AND v_almacen IS DISTINCT FROM v_venta.id_almacen)
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
    -- Correcciones (reserva / registro): solo se exige el mismo tipo de cilindro; el gas
    -- y el propietario pueden diferir. El cambio físico mueve gas del producto del
    -- balón devuelto, así que conserva la regla completa.
    IF v_new.id_tipo_balon IS DISTINCT FROM v_old.id_tipo_balon THEN
        RAISE EXCEPTION 'El reemplazo debe ser del mismo tipo de cilindro';
    END IF;
    IF NOT (v_reserva OR v_registro) AND (
       v_new.id_producto_gas IS DISTINCT FROM v_old.id_producto_gas
       OR v_new.id_propietario IS DISTINCT FROM v_old.id_propietario
       OR v_new.id_cliente_propietario IS DISTINCT FROM v_old.id_cliente_propietario) THEN
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
    v_limite := ven_cantidad_gas_balon_vsd(p_id,v_old_id,v_original);
    IF (v_reserva OR v_registro) AND (v_salida <> 0 OR v_devuelto <> 0 OR v_condicion <> 'DISPONIBLE') THEN
        RAISE EXCEPTION 'Una corrección no mueve gas y devuelve el balón anterior a disponible';
    END IF;
    IF NOT v_reserva AND NOT v_registro AND (COALESCE(v_capacidad, 0) <= 0 OR COALESCE(v_limite, 0) <= 0
        OR v_salida <> LEAST(v_capacidad, v_limite) OR v_devuelto > v_salida) THEN
        RAISE EXCEPTION 'La cantidad de salida debe coincidir con lo vendido y la capacidad del balón; el remanente no puede superarla';
    END IF;
    SELECT pd.* INTO v_pd FROM bal_prestamo_detalle pd
        JOIN LATERAL (SELECT id FROM bal_prestamo pr WHERE pr.id = pd.id_prestamo AND pr.id_comprobante_venta = p_id AND pr.estado = 1) pr ON true
        WHERE pd.id_balon = v_old_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO'
        FOR UPDATE OF pd;
    -- Correcciones: si el préstamo no quedó ligado a la venta, se busca el préstamo
    -- vigente del balón para el cliente de la venta. Se reemplaza más abajo.
    IF v_pd.id IS NULL AND (v_reserva OR v_registro) THEN
        SELECT pd.* INTO v_pd FROM bal_prestamo_detalle pd
            JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1 AND pr.id_cliente = v_venta.id_cliente
            WHERE pd.id_balon = v_old_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO'
            ORDER BY pd.id DESC LIMIT 1
            FOR UPDATE OF pd;
    END IF;
    IF NOT (v_reserva OR v_registro) AND v_old.id_estado_balon = (SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre='PRESTADO_CLIENTE' LIMIT 1) AND v_pd.id IS NULL THEN
        RAISE EXCEPTION 'El préstamo del balón no pertenece a esta venta';
    END IF;
    SELECT lo.id INTO v_estado_dest FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre=v_condicion AND lo.estado=1 LIMIT 1;
    IF v_estado_dest IS NULL THEN RAISE EXCEPTION 'La condición de devolución no está configurada'; END IF;
    IF NOT v_reserva AND NOT v_registro AND v_condicion='DISPONIBLE' AND (v_old.fecha_proxima_prueba_hidrostatica IS NULL OR v_old.fecha_proxima_prueba_hidrostatica<CURRENT_DATE) THEN
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
    IF v_condicion = 'EN_MANTENIMIENTO' AND v_devuelto <> 0 THEN RAISE EXCEPTION 'Un balón para mantenimiento no puede reponer gas utilizable'; END IF;
    IF v_devuelto > 0 THEN
        v_result := inv_registrar_movimiento(p_naturaleza=>'PRODUCTO', p_codigo_tipo_movimiento=>'INGRESO',
            p_id_producto=>v_producto, p_cantidad=>v_devuelto, p_id_almacen_origen=>v_almacen,
            p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
            p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END IF;
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
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF v_registro THEN
        -- El correcto queda exactamente donde figuraba el registrado (con el cliente).
        UPDATE bal_balon SET id_estado_balon=v_old.id_estado_balon,id_almacen=v_old.id_almacen,
            id_cliente_ubicacion=v_old.id_cliente_ubicacion,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now() WHERE id=v_new_id;
    END IF;
    IF v_registro OR (NOT v_reserva AND v_tipo IN ('01','03')) THEN
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF v_pd.id IS NOT NULL AND (v_reserva OR v_registro) THEN
        -- Corrección: el préstamo del balón registrado se da de baja (no es una devolución:
        -- el cliente nunca lo tuvo) y se genera uno nuevo con el balón correcto, con las
        -- mismas fechas y condiciones. Garantía y recojo pendiente pasan al nuevo.
        UPDATE bal_prestamo_detalle SET estado=0,
            observacion=left(concat_ws(' · ', NULLIF(observacion,''), 'Anulado por corrección de balón: ' || v_motivo), 500),
            id_usuario_modificacion=p_id_usuario, fecha_modificacion=now() WHERE id=v_pd.id;
        INSERT INTO bal_prestamo_detalle(id_prestamo,id_balon,id_producto,motivo_especifico,fecha_entregado,fecha_prestamo,
            dias_prestamo,fecha_vencimiento,serie_guia_entrega,numero_guia_entrega,id_estado,observacion,
            id_doc_salida_entrega,rol,id_usuario_creacion,id_usuario_modificacion)
        VALUES (v_pd.id_prestamo,v_new_id,COALESCE(v_pd.id_producto,v_producto),v_pd.motivo_especifico,v_pd.fecha_entregado,
            v_pd.fecha_prestamo,v_pd.dias_prestamo,v_pd.fecha_vencimiento,v_pd.serie_guia_entrega,v_pd.numero_guia_entrega,
            v_pd.id_estado,left('Corrección de balón: ' || v_motivo, 500),v_pd.id_doc_salida_entrega,v_pd.rol,p_id_usuario,p_id_usuario)
        RETURNING id INTO v_prestamo_nuevo;
        UPDATE ven_garantia SET id_prestamo_detalle=v_prestamo_nuevo,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_prestamo_detalle=v_pd.id AND estado=1;
        UPDATE age_actividad_item i SET id_balon=v_new_id,id_prestamo_detalle=v_prestamo_nuevo,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            FROM age_actividad a, gen_lista_opciones ea, gen_lista_opciones ta
            WHERE i.id_actividad=a.id AND a.id_estado_actividad=ea.id AND a.id_tipo_actividad=ta.id
              AND i.id_prestamo_detalle=v_pd.id AND i.estado=1 AND a.estado=1 AND ea.nombre='PENDIENTE' AND ta.nombre='RECOJO';
        -- La venta queda ligada al préstamo aunque se hubiera creado sin referencia.
        UPDATE bal_prestamo SET id_comprobante_venta=COALESCE(id_comprobante_venta,p_id),
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now() WHERE id=v_pd.id_prestamo;
    ELSIF v_pd.id IS NOT NULL THEN
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

DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json,
  p_motivo_correccion varchar,
  p_version_esperada varchar
);

-- Firma vigente (con reemplazo de balones). La anterior se elimina arriba: si
-- quedaran ambas, la llamada con 27 argumentos sería ambigua.
DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json,
  p_motivo_correccion varchar,
  p_version_esperada varchar,
  p_cambios_balon jsonb
);

CREATE OR REPLACE FUNCTION public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_detalles json DEFAULT NULL::json,
  p_id_tipo_operacion_sunat integer DEFAULT NULL::integer,
  p_id_comprobante_origen integer DEFAULT NULL::integer,
  p_id_motivo_nota integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_venta integer DEFAULT NULL::integer,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_tipo_cambio numeric DEFAULT NULL::numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_periodo_contable character varying DEFAULT NULL::character varying,
  p_operacion character varying DEFAULT NULL::character varying,
  p_id_estado integer DEFAULT NULL::integer,
  p_cuotas json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_origen_pos character varying DEFAULT NULL::character varying,
  p_pagos json DEFAULT NULL::json,
  p_motivo_correccion varchar DEFAULT NULL,
  p_version_esperada varchar DEFAULT NULL,
  -- [{ "idBalonActual": n, "idBalonNuevo": m }]: reemplazo de cilindros reservados del detalle.
  p_cambios_balon jsonb DEFAULT NULL
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_err_pagos TEXT;
    v_antes JSONB;
    v_edicion_segura BOOLEAN;
    v_dependencias BOOLEAN;
    v_version TEXT;
    v_estado_sunat VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_sub_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_cuota INTEGER;
    v_numero_cuota INTEGER;
    v_recalcular BOOLEAN := FALSE;
    v_codigo_tipo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_fecha DATE;
    v_id_almacen_actual INTEGER;
    v_id_almacen_nuevo INTEGER;
    v_id_tipo_venta INTEGER;
    v_es_nota_credito BOOLEAN := FALSE;
    v_mueve_stock BOOLEAN := FALSE;
    v_afecta_stock BOOLEAN;
    v_id_tipo_mov_salida INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_qty_antigua NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_id_tipo_mov_aplicar INTEGER;
    v_cantidad_aplicar NUMERIC(12,4);
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
    -- Líneas atadas a balones, gas, alquiler o garantía: solo admiten cambio de precio.
    v_items_bloqueados INTEGER[] := ARRAY[]::INTEGER[];
    v_bloqueadas_antes JSONB;
    v_bloqueadas_nuevas JSONB;
    -- Caja: el arqueo se calcula con las líneas de cobro de la venta.
    v_total_anterior NUMERIC(12,4);
    v_total_nuevo NUMERIC(12,4);
    v_fecha_anterior DATE;
    v_id_sucursal_anterior INTEGER;
    v_id_sucursal_nueva INTEGER;
    v_afecta_caja BOOLEAN;
    v_lineas_pago INTEGER;
    v_fecha_caja DATE;
    v_id_sucursal_caja INTEGER;
    -- Reemplazo de balones
    v_cambio JSONB;
    v_id_balon_actual INTEGER;
    v_id_balon_nuevo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    PERFORM ven_validar_edicion_pre_emision(p_id);
    SELECT xmin::text INTO v_version FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    v_antes := ven_obtener_comprobante(p_id)::jsonb;

    SELECT
        es.nombre,
        tc.descripcion,
        c.serie,
        c.numero,
        c.fecha,
        c.id_almacen,
        c.id_tipo_venta
    INTO
        v_estado_sunat,
        v_codigo_tipo,
        v_serie,
        v_numero,
        v_fecha,
        v_id_almacen_actual,
        v_id_tipo_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'error', 'No se puede editar un comprobante con estado SUNAT ' || v_estado_sunat,
            'registro', NULL
        );
    END IF;

    IF v_codigo_tipo IN ('NV', 'VSD') AND EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'No se puede editar una venta sin documento que ya fue convertida a boleta/factura',
            'registro',
            NULL
        );
    END IF;

    v_edicion_segura := v_codigo_tipo IN ('NV', 'VSD', '01', '03');
    v_dependencias := EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante = p_id AND estado = 1 AND (id_balon IS NOT NULL OR COALESCE(descripcion,'') ~* 'garant[ií]a'))
        OR EXISTS (SELECT 1 FROM bal_prestamo WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_movimiento_recarga WHERE id_comprobante = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_alquiler WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON')
        OR EXISTS (SELECT 1 FROM doc_salida WHERE id_venta = p_id AND estado = 1);
    IF v_edicion_segura THEN
        IF p_id_usuario_auditoria IS NULL OR length(btrim(COALESCE(p_motivo_correccion, ''))) < 5 THEN
            RAISE EXCEPTION 'Indique el motivo de la corrección (mínimo 5 caracteres) y el usuario';
        END IF;
        IF p_version_esperada IS NULL OR p_version_esperada <> v_version THEN
            RAISE EXCEPTION 'La venta cambió desde que se abrió. Recargue y revise los datos';
        END IF;
        IF p_id_comprobante_origen IS NOT NULL OR p_id_tipo_venta IS NOT NULL OR p_id_estado IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede cambiar el origen, tipo o estado de una venta mediante corrección';
        END IF;
    END IF;

    -- ---- Reemplazo de balones del detalle ----
    -- Se aplica antes de validar el detalle: las líneas que llegan ya traen el
    -- balón nuevo. Cada cambio es una corrección (ven_cambiar_balon_vsd) que no mueve gas:
    -- el anterior vuelve a DISPONIBLE y el nuevo toma su lugar.
    --   * PENDIENTE_ENVIO (reservado para despacho) → CORRECCION_RESERVA.
    --   * Ya con el cliente (mostrador: EN_PODER_CLIENTE / PRESTADO_CLIENTE) →
    --     CORRECCION_REGISTRO: se registró otro código; el préstamo pasa al correcto.
    IF p_cambios_balon IS NOT NULL AND jsonb_typeof(p_cambios_balon) = 'array'
       AND jsonb_array_length(p_cambios_balon) > 0 THEN
        IF NOT v_edicion_segura THEN
            RAISE EXCEPTION 'Solo se pueden reemplazar balones en ventas, facturas o boletas';
        END IF;
        IF (SELECT count(*) FROM jsonb_array_elements(p_cambios_balon) e) <>
           (SELECT count(DISTINCT (e->>'idBalonActual')::integer) FROM jsonb_array_elements(p_cambios_balon) e)
           OR (SELECT count(*) FROM jsonb_array_elements(p_cambios_balon) e) <>
           (SELECT count(DISTINCT (e->>'idBalonNuevo')::integer) FROM jsonb_array_elements(p_cambios_balon) e) THEN
            RAISE EXCEPTION 'Cada balón solo puede reemplazarse una vez y por un cilindro distinto en la misma corrección';
        END IF;

        FOR v_cambio IN SELECT e FROM jsonb_array_elements(p_cambios_balon) e
        LOOP
            v_id_balon_actual := NULLIF(v_cambio->>'idBalonActual', '')::integer;
            v_id_balon_nuevo := NULLIF(v_cambio->>'idBalonNuevo', '')::integer;

            IF v_id_balon_actual IS NULL OR v_id_balon_nuevo IS NULL OR v_id_balon_actual = v_id_balon_nuevo THEN
                RAISE EXCEPTION 'Indique el balón a reemplazar y uno distinto como reemplazo';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM ven_comprobante_detalle
                WHERE id_comprobante = p_id AND estado = 1 AND id_balon = v_id_balon_actual) THEN
                RAISE EXCEPTION 'El balón % no está en el detalle de esta venta', COALESCE(
                    (SELECT codigo_balon FROM bal_balon WHERE id = v_id_balon_actual), '#' || v_id_balon_actual);
            END IF;
            -- Sin despacho asignado: ni en una orden de salida en borrador o con reparto
            -- pendiente (ven_cambiar_balon_vsd ya revisa actividades pendientes).
            IF EXISTS (
                SELECT 1
                FROM doc_salida_detalle dd
                JOIN doc_salida d ON d.id = dd.id_doc_salida AND d.estado = 1
                JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
                WHERE dd.id_balon = v_id_balon_nuevo AND dd.estado = 1
                  AND ec.nombre <> 'ANULADA'
                  AND (ec.nombre = 'BORRADOR' OR EXISTS (
                      SELECT 1 FROM age_actividad a
                      JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                      WHERE a.id_doc_salida = d.id AND a.estado = 1
                        AND ea.nombre NOT IN ('REALIZADA', 'CANCELADA')))
            ) THEN
                RAISE EXCEPTION 'El balón % ya está asignado a un despacho pendiente', COALESCE(
                    (SELECT codigo_balon FROM bal_balon WHERE id = v_id_balon_nuevo), '#' || v_id_balon_nuevo);
            END IF;

            PERFORM ven_cambiar_balon_vsd(p_id, jsonb_build_object(
                'tipoOperacion', CASE WHEN (
                    SELECT eb.nombre FROM bal_balon b
                    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    WHERE b.id = v_id_balon_actual
                ) = 'PENDIENTE_ENVIO' THEN 'CORRECCION_RESERVA' ELSE 'CORRECCION_REGISTRO' END,
                'solicitud', gen_random_uuid(),
                'versionEsperada', (SELECT xmin::text FROM ven_comprobante WHERE id = p_id),
                'idBalonActual', v_id_balon_actual,
                'idBalonNuevo', v_id_balon_nuevo,
                'idAlmacen', v_id_almacen_actual,
                'cantidadGasDevuelta', 0,
                'cantidadGasSalida', 0,
                'condicionDevolucion', 'DISPONIBLE',
                'motivo', btrim(p_motivo_correccion)
            ), p_id_usuario_auditoria);
        END LOOP;
    END IF;
    -- Ítems: una línea que trae el ítem de una línea vigente lo conserva; las nuevas
    -- (o un ítem repetido) toman uno libre después del mayor usado en el comprobante.
    IF p_detalles IS NOT NULL AND json_typeof(p_detalles) = 'array' THEN
        SELECT json_agg(x.v ORDER BY x.o) INTO p_detalles
        FROM (
            SELECT k.o, jsonb_set(k.v, '{item}', to_jsonb(CASE WHEN k.conserva THEN k.it
                ELSE m.max_item + row_number() OVER (PARTITION BY k.conserva ORDER BY k.o) END)) AS v
            FROM (
                SELECT j.o, j.v, j.it,
                    (j.it IS NOT NULL
                     AND EXISTS (SELECT 1 FROM ven_comprobante_detalle d
                         WHERE d.id_comprobante = p_id AND d.estado = 1 AND d.item = j.it)
                     AND row_number() OVER (PARTITION BY j.it ORDER BY j.o) = 1) AS conserva
                FROM (
                    SELECT e.value::jsonb AS v, e.ordinality AS o,
                        NULLIF(e.value->>'item', '')::integer AS it
                    FROM json_array_elements(p_detalles) WITH ORDINALITY e(value, ordinality)
                ) j
            ) k
            CROSS JOIN (SELECT COALESCE(MAX(item), 0) AS max_item
                FROM ven_comprobante_detalle WHERE id_comprobante = p_id) m
        ) x;
    END IF;

    IF v_dependencias THEN
        SELECT COALESCE(array_agg(d.item), ARRAY[]::INTEGER[]) INTO v_items_bloqueados
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.id_comprobante = p_id AND d.estado = 1
          AND (d.id_balon IS NOT NULL
               OR COALESCE(d.descripcion, '') ~* 'garant[ií]a'
               OR COALESCE(p.es_gas, FALSE)
               OR COALESCE(p.es_alquilable, FALSE));
    END IF;

    IF v_dependencias AND p_detalles IS NOT NULL THEN
        SELECT jsonb_agg(jsonb_build_array(d.item, d.id_producto, d.cantidad, d.id_balon,
                 d.id_unidad_medida, d.capacidad_cilindro, d.id_estado_cilindro,
                 COALESCE(d.descripcion, '')) ORDER BY d.item)
        INTO v_bloqueadas_antes
        FROM ven_comprobante_detalle d
        WHERE d.id_comprobante = p_id AND d.estado = 1 AND d.item = ANY(v_items_bloqueados);

        SELECT jsonb_agg(jsonb_build_array((j.value->>'item')::integer,
                 (j.value->>'id_producto')::integer, (j.value->>'cantidad')::numeric,
                 NULLIF((j.value->>'id_balon')::integer, 0), NULLIF((j.value->>'id_unidad_medida')::integer, 0),
                 NULLIF((j.value->>'capacidad_cilindro')::numeric, 0), NULLIF((j.value->>'id_estado_cilindro')::integer, 0),
                 COALESCE(j.value->>'descripcion', '')) ORDER BY (j.value->>'item')::integer)
        INTO v_bloqueadas_nuevas
        FROM json_array_elements(p_detalles) j
        WHERE (j.value->>'item')::integer = ANY(v_items_bloqueados);

        IF v_bloqueadas_antes IS DISTINCT FROM v_bloqueadas_nuevas THEN
            RAISE EXCEPTION 'Las líneas con balón, gas, alquiler o garantía vinculados no se pueden quitar ni cambiar de producto o cantidad. Use Cambio de balón para el movimiento físico; sí puede corregir su precio y agregar o editar los demás productos';
        END IF;

        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            WHERE NOT ((j.value->>'item')::integer = ANY(v_items_bloqueados))
              AND (NULLIF((j.value->>'id_balon')::integer, 0) IS NOT NULL
                   OR COALESCE((j.value->>'no_mueve_kardex')::boolean, false))) THEN
            RAISE EXCEPTION 'La corrección de productos no puede crear una salida de balón ni omitir el kardex';
        END IF;
    END IF;

    IF v_dependencias AND (
        (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)
        OR (p_id_almacen IS NOT NULL AND p_id_almacen IS DISTINCT FROM v_id_almacen_actual)) THEN
        RAISE EXCEPTION 'La venta tiene balones, préstamos, recargas u órdenes vinculadas; la corrección conserva el cliente y el almacén';
    END IF;
    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RAISE EXCEPTION 'Debe registrar al menos un detalle';
        END IF;
        PERFORM id FROM pro_producto WHERE id IN (SELECT (value->>'id_producto')::integer FROM json_array_elements(p_detalles)) ORDER BY id FOR SHARE;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            GROUP BY COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer) HAVING count(*)>1) THEN
            RAISE EXCEPTION 'Los ítems del detalle no pueden estar duplicados';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            LEFT JOIN pro_producto p ON p.id = (j.value->>'id_producto')::integer AND p.estado = 1
            WHERE p.id IS NULL OR (j.value->>'cantidad')::numeric <= 0
                OR COALESCE((j.value->>'precio_unitario')::numeric, -1) < 0
                OR COALESCE((j.value->>'descuento')::numeric, 0) < 0
                OR COALESCE((j.value->>'porcentaje_igv')::numeric, 18) NOT BETWEEN 0 AND 100
                OR COALESCE((j.value->>'descuento')::numeric, 0) > (j.value->>'cantidad')::numeric * (j.value->>'precio_unitario')::numeric) THEN
            RAISE EXCEPTION 'Detalle inválido: producto inactivo, cantidad, precio o descuento incorrectos';
        END IF;
        IF NOT v_dependencias AND EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            WHERE NULLIF((j.value->>'id_balon')::integer, 0) IS NOT NULL
               OR COALESCE((j.value->>'no_mueve_kardex')::boolean, false)) THEN
            RAISE EXCEPTION 'La corrección de productos no puede crear una salida de balón ni omitir el kardex';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            JOIN ven_comprobante_detalle d ON d.id_comprobante=p_id AND d.estado=1
                AND d.item=COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer)
            WHERE COALESCE(d.descripcion,'') ~* 'garant[ií]a' AND
                jsonb_build_array(d.precio_unitario,COALESCE(d.descuento,0),d.porcentaje_igv,d.id_afectacion_igv)
                IS DISTINCT FROM jsonb_build_array((j.value->>'precio_unitario')::numeric,
                    COALESCE((j.value->>'descuento')::numeric,0),COALESCE((j.value->>'porcentaje_igv')::numeric,18),
                    NULLIF((j.value->>'id_afectacion_igv')::integer,0))) THEN
            RAISE EXCEPTION 'Los importes de garantía deben corregirse desde el módulo de garantías';
        END IF;
    END IF;
    IF fin_cuenta_documento_tiene_pagos(p_id,NULL) AND (
        p_cuotas IS NOT NULL OR p_id_condicion_pago IS NOT NULL OR p_id_moneda IS NOT NULL
        OR (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)) THEN
        RAISE EXCEPTION 'La cuenta por cobrar tiene pagos; no se pueden reasignar cliente, moneda, condición o cuotas desde la corrección';
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');
    v_mueve_stock := (v_codigo_tipo IN ('01', '03', '07', 'NV', 'VSD'));
    v_id_almacen_nuevo := COALESCE(p_id_almacen, v_id_almacen_actual);
    v_fecha := COALESCE(p_fecha, v_fecha);
    v_id_tipo_venta := COALESCE(p_id_tipo_venta, v_id_tipo_venta);

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
        END IF;

        v_recalcular := TRUE;

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

            IF v_id_producto IS NULL OR v_cantidad <= 0 THEN
                RETURN json_build_object('error', 'Detalle inválido: producto y cantidad son obligatorios', 'registro', NULL);
            END IF;

            SELECT
                REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
                COALESCE(p.es_gas, FALSE)
            INTO v_nombre_unidad, v_es_gas
            FROM pro_producto p
            LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
            WHERE p.id = v_id_producto;

            IF NOT COALESCE(v_es_gas, FALSE)
               AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
               AND v_cantidad <> TRUNC(v_cantidad)
            THEN
                RETURN json_build_object(
                    'error',
                    'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                        || ' debe ser entera (unidad de medida UNID)',
                    'registro',
                    NULL
                );
            END IF;

            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
                IF v_codigo_afectacion = '20' THEN
                    v_exonerado_total := v_exonerado_total + v_valor_linea;
                END IF;
            END IF;

            v_descuento_total := v_descuento_total + v_descuento_linea;
            v_valor_venta_total := v_valor_venta_total + v_valor_linea;
            v_igv_total := v_igv_total + v_impuesto_linea;
            v_sub_total := v_sub_total + v_importe_linea;
            v_total_importe := v_total_importe + v_importe_linea;
        END LOOP;
    END IF;

    IF v_mueve_stock AND (p_detalles IS NOT NULL OR p_id_almacen IS NOT NULL) THEN
        IF EXISTS (
            SELECT 1
            FROM ven_comprobante_detalle d
            INNER JOIN pro_producto p ON p.id = d.id_producto
            WHERE d.id_comprobante = p_id
              AND d.estado = 1
              AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
        ) OR (
            p_detalles IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM json_array_elements(p_detalles) j
                INNER JOIN pro_producto p ON p.id = (j.value->>'id_producto')::INTEGER
                WHERE ven_producto_mueve_kardex_venta(p.id, j.value->>'descripcion')
            )
        ) THEN
            IF v_id_almacen_nuevo IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Debe indicar el almacén para ajustar stock de los productos',
                    'registro',
                    NULL
                );
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_nuevo AND estado = 1
            ) THEN
                RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
            END IF;

            SELECT lo.id INTO v_id_tipo_mov_salida
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_mov_ingreso
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_salida IS NULL OR v_id_tipo_mov_ingreso IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontraron tipos de movimiento SALIDA/INGRESO',
                    'registro',
                    NULL
                );
            END IF;

            SELECT lo.nombre INTO v_nombre_tipo_venta
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_tipo_venta;

            IF p_detalles IS NULL THEN
                IF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                    FOR v_id_producto, v_qty_antigua IN
                        SELECT d.id_producto, SUM(d.cantidad)
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    LOOP
                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_actual,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;

                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        ELSE
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_qty_antigua THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_qty_antigua
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_nuevo,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (aplicar)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;
                    END LOOP;
                END IF;
            ELSIF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                FOR v_id_producto, v_qty_antigua IN
                    SELECT d.id_producto, SUM(d.cantidad)
                    FROM ven_comprobante_detalle d
                    INNER JOIN pro_producto p ON p.id = d.id_producto
                    WHERE d.id_comprobante = p_id
                      AND d.estado = 1
                      AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                    GROUP BY d.id_producto
                LOOP
                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    ELSE
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_antigua,
                        v_id_almacen_actual,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;

                FOR v_id_producto, v_qty_nueva IN
                    SELECT
                        (value->>'id_producto')::INTEGER,
                        SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                    FROM json_array_elements(p_detalles)
                    GROUP BY (value->>'id_producto')::INTEGER
                LOOP
                    IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    ELSE
                        SELECT COALESCE(s.stock, 0)
                        INTO v_stock_disponible
                        FROM pro_stock s
                        WHERE s.id_almacen = v_id_almacen_nuevo
                          AND s.id_producto = v_id_producto
                          AND s.estado = 1;

                        IF COALESCE(v_stock_disponible, 0) < v_qty_nueva THEN
                            RAISE EXCEPTION '%', format(
                                    'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                    COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                    COALESCE(v_stock_disponible, 0),
                                    v_qty_nueva
                                );
                        END IF;
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_nueva,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            ELSE
                FOR v_id_producto, v_qty_antigua, v_qty_nueva IN
                    SELECT
                        COALESCE(o.id_producto, n.id_producto),
                        COALESCE(o.cantidad, 0),
                        COALESCE(n.cantidad, 0)
                    FROM (
                        SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    ) o
                    FULL OUTER JOIN (
                        SELECT
                            (value->>'id_producto')::INTEGER AS id_producto,
                            SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                        FROM json_array_elements(p_detalles)
                        GROUP BY (value->>'id_producto')::INTEGER
                    ) n ON n.id_producto = o.id_producto
                    INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
                    WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
                LOOP
                    v_delta_stock := v_qty_nueva - v_qty_antigua;
                    IF v_delta_stock = 0 THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        IF v_delta_stock > 0 THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    ELSE
                        IF v_delta_stock > 0 THEN
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_delta_stock
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_id_tipo_mov_aplicar = v_id_tipo_mov_salida THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_cantidad_aplicar,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END IF;

    UPDATE ven_comprobante
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_tipo_operacion_sunat = COALESCE(p_id_tipo_operacion_sunat, id_tipo_operacion_sunat),
        id_comprobante_origen = COALESCE(p_id_comprobante_origen, id_comprobante_origen),
        id_motivo_nota = COALESCE(p_id_motivo_nota, id_motivo_nota),
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_tipo_venta = COALESCE(p_id_tipo_venta, id_tipo_venta),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tipo_cambio = COALESCE(p_tipo_cambio, tipo_cambio),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_condicion_pago = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_moneda = COALESCE(p_id_moneda, id_moneda),
        id_medio_pago = COALESCE(p_id_medio_pago, id_medio_pago),
        sub_total = CASE WHEN v_recalcular THEN v_sub_total ELSE sub_total END,
        descuento = CASE WHEN v_recalcular THEN v_descuento_total ELSE descuento END,
        valor_venta = CASE WHEN v_recalcular THEN v_valor_venta_total ELSE valor_venta END,
        igv = CASE WHEN v_recalcular THEN v_igv_total ELSE igv END,
        total_importe = CASE WHEN v_recalcular THEN v_total_importe ELSE total_importe END,
        exonerado = CASE WHEN v_recalcular THEN v_exonerado_total ELSE exonerado END,
        glosa = COALESCE(p_glosa, glosa),
        observaciones = COALESCE(p_observaciones, observaciones),
        periodo_contable = COALESCE(p_periodo_contable, periodo_contable),
        operacion = COALESCE(p_operacion, operacion),
        origen_pos = COALESCE(NULLIF(TRIM(p_origen_pos), ''), origen_pos),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
        -- Las líneas vinculadas se conservan (solo se actualiza su precio); el resto se reemplaza.
        UPDATE ven_comprobante_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1
          AND NOT (item = ANY(v_items_bloqueados));
        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
            END IF;

            IF COALESCE(NULLIF((v_detalle->>'item')::integer, 0), v_item) = ANY(v_items_bloqueados) THEN
                UPDATE ven_comprobante_detalle SET
                    precio_unitario = v_precio_unitario, descuento = v_descuento_linea,
                    valor_venta = v_valor_linea, porcentaje_igv = v_porcentaje_igv,
                    id_afectacion_igv = NULLIF((v_detalle->>'id_afectacion_igv')::integer, 0),
                    impuesto = v_impuesto_linea, importe = v_importe_linea,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = now()
                WHERE id_comprobante = p_id AND estado = 1
                  AND item = COALESCE(NULLIF((v_detalle->>'item')::integer, 0), v_item);
                CONTINUE;
            END IF;
            INSERT INTO ven_comprobante_detalle (
                id_comprobante, item, id_producto, descripcion, id_unidad_medida,
                cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
                id_afectacion_igv, impuesto, importe,
                id_balon, capacidad_cilindro, id_estado_cilindro,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id,
                COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
                v_id_producto,
                NULLIF(v_detalle->>'descripcion', ''),
                NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
                v_cantidad,
                v_precio_unitario,
                v_descuento_linea,
                v_valor_linea,
                v_porcentaje_igv,
                NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0),
                v_impuesto_linea,
                v_importe_linea,
                NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
                NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
                NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_cuota
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_cuotas
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        IF json_typeof(p_cuotas) = 'array' THEN
            FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
            LOOP
                v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
                IF v_numero_cuota <= 0 THEN
                    CONTINUE;
                END IF;

                INSERT INTO ven_cuotas (
                    id_comprobante, numero_cuota, fecha_vencimiento, monto,
                    monto_pagado, id_estado,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id,
                    v_numero_cuota,
                    (v_cuota->>'fecha_vencimiento')::DATE,
                    COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                    COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                    COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                    p_id_usuario_auditoria,
                    p_id_usuario_auditoria
                );
            END LOOP;
        END IF;
    END IF;

    -- ---- Caja ----
    -- La caja del día no guarda copia de la venta: suma en vivo sus líneas de cobro
    -- (ven_comprobante_pago) o, si no tiene, el total de la cabecera. Si cambia el
    -- importe, la fecha o la sucursal, el arqueo de la(s) caja(s) afectada(s) cambia:
    -- no se permite si alguna ya está cerrada, y las líneas de cobro se ajustan al total.
    v_total_anterior := ROUND(COALESCE((v_antes->'registro'->>'total_importe')::NUMERIC, 0), 4);
    v_fecha_anterior := (v_antes->'registro'->>'fecha')::DATE;
    v_id_sucursal_anterior := NULLIF(v_antes->'registro'->>'id_sucursal', '')::INTEGER;
    SELECT ROUND(COALESCE(c.total_importe, 0), 4), c.fecha, c.id_sucursal
    INTO v_total_nuevo, v_fecha, v_id_sucursal_nueva
    FROM ven_comprobante c WHERE c.id = p_id;

    IF v_total_nuevo IS DISTINCT FROM v_total_anterior
       OR v_fecha IS DISTINCT FROM v_fecha_anterior
       OR v_id_sucursal_nueva IS DISTINCT FROM v_id_sucursal_anterior
       OR p_pagos IS NOT NULL THEN

        SELECT EXISTS (
            SELECT 1 FROM ven_pagos_de_comprobante(p_id) pg
            WHERE NOT fin_medio_pago_flag(pg.id_medio_pago, 'ES_CREDITO')
        ) OR (p_pagos IS NOT NULL AND json_typeof(p_pagos) = 'array' AND EXISTS (
            SELECT 1 FROM json_array_elements(p_pagos) j
            WHERE NOT fin_medio_pago_flag(NULLIF(j.value->>'idMedioPago', '')::INTEGER, 'ES_CREDITO')
        ))
        INTO v_afecta_caja;

        IF v_afecta_caja THEN
            FOR v_fecha_caja, v_id_sucursal_caja IN
                SELECT DISTINCT f.fecha, f.id_sucursal
                FROM (VALUES (v_fecha_anterior, v_id_sucursal_anterior), (v_fecha, v_id_sucursal_nueva)) f(fecha, id_sucursal)
                WHERE f.fecha IS NOT NULL
            LOOP
                IF EXISTS (
                    SELECT 1
                    FROM fin_caja_sesion s
                    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
                    WHERE s.estado = 1
                      AND s.fecha = v_fecha_caja
                      AND COALESCE(s.id_sucursal, 0) = COALESCE(v_id_sucursal_caja, 0)
                      AND UPPER(est.nombre) = 'CERRADA'
                ) THEN
                    RAISE EXCEPTION 'La caja del % ya está cerrada y esta corrección cambia su arqueo (total % → %). Reabra la caja de esa fecha para corregir la venta',
                        to_char(v_fecha_caja, 'DD/MM/YYYY'),
                        gen_formato_cantidad(v_total_anterior),
                        gen_formato_cantidad(v_total_nuevo);
                END IF;
            END LOOP;
        END IF;

        -- Sin pagos explícitos: un cobro de un solo medio sigue al nuevo total;
        -- con varios medios hay que indicar cómo se reparte.
        IF p_pagos IS NULL AND v_total_nuevo IS DISTINCT FROM v_total_anterior THEN
            SELECT COUNT(*) INTO v_lineas_pago
            FROM ven_comprobante_pago WHERE id_comprobante = p_id AND estado = 1;

            IF v_lineas_pago = 1 THEN
                IF v_total_nuevo > 0 THEN
                    UPDATE ven_comprobante_pago
                    SET monto = v_total_nuevo,
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id_comprobante = p_id AND estado = 1;
                ELSE
                    DELETE FROM ven_comprobante_pago WHERE id_comprobante = p_id;
                END IF;
            ELSIF v_lineas_pago > 1 THEN
                RAISE EXCEPTION 'La venta se cobró con varios medios de pago y el total cambia de % a %. Indique cómo se reparte el nuevo total entre los medios de pago',
                    gen_formato_cantidad(v_total_anterior),
                    gen_formato_cantidad(v_total_nuevo)
                    USING ERRCODE = '22023';
            END IF;
        END IF;
    END IF;

    IF NOT v_es_nota_credito THEN
        PERFORM ven_sincronizar_cxc_venta(p_id, p_id_usuario_auditoria);
    END IF;

    v_err_pagos := ven_sincronizar_pagos_comprobante(p_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    IF v_edicion_segura THEN
        INSERT INTO ven_vsd_operacion(id_comprobante, tipo, motivo, datos, anterior, posterior, id_usuario)
        VALUES (p_id, 'CORRECCION', btrim(p_motivo_correccion),
            jsonb_build_object('version', p_version_esperada), v_antes,
            ven_obtener_comprobante(p_id)::jsonb, p_id_usuario_auditoria);
    END IF;
    RETURN ven_obtener_comprobante(p_id);
END;
$function$;

COMMIT;
