-- Ajuste autorizado: neutralizar exclusivamente la salida de Ruta pueblos #1.
-- Se conservan los movimientos originales y se agrega una compensación por cada uno.
-- Ejecutar junto con la migración de solo historial, en una única transacción.
DO $correccion$
DECLARE
    r RECORD;
    v_stock RECORD;
    v_balon RECORD;
    v_tipo_ajuste integer;
    v_tipo_retorno integer;
    v_usuario integer;
    v_total integer;
    v_compensados integer;
BEGIN
    SET LOCAL TIME ZONE 'America/Lima';
    PERFORM pg_advisory_xact_lock(20261031, 1);
    SELECT id_usuario_modificacion INTO v_usuario FROM bal_ruta_pueblo
    WHERE id=1 AND estado=1 AND id_almacen=2
      AND fecha=DATE '2026-10-30' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La ruta #1 no coincide con la ruta auditada'; END IF;
    SELECT count(*) INTO v_total FROM inv_movimiento m
    JOIN gen_lista_opciones td ON td.id=m.id_tipo_documento_origen
    JOIN gen_lista l ON l.id=td.id_lista AND l.nombre='TipoDocumentoRef'
    WHERE td.nombre='RUTA_PUEBLO' AND m.id_documento_origen=1
      AND m.id BETWEEN 971 AND 1018 AND m.estado=1;
    IF v_total<>48 THEN RAISE EXCEPTION 'Los 48 movimientos originales han cambiado'; END IF;
    SELECT count(*) INTO v_compensados FROM inv_movimiento
    WHERE id_movimiento_padre BETWEEN 971 AND 1018 AND estado=1
      AND glosa LIKE 'Restitución ruta histórica #1:%';
    IF v_compensados=48 THEN RETURN; END IF;
    IF v_compensados<>0 THEN RAISE EXCEPTION 'Compensación parcial: requiere revisión'; END IF;
    -- Bloquear solo durante esta corrección para impedir ventas concurrentes entre comprobación y ajuste.
    LOCK TABLE inv_movimiento, pro_stock, bal_balon IN SHARE ROW EXCLUSIVE MODE;
    IF EXISTS (
        SELECT 1 FROM inv_movimiento x WHERE x.estado=1 AND x.id>1018
        AND (x.id_producto IN (SELECT id_producto FROM inv_movimiento WHERE id BETWEEN 971 AND 1018)
          OR x.id_balon IN (SELECT id_balon FROM inv_movimiento WHERE id BETWEEN 971 AND 1018))
    ) THEN RAISE EXCEPTION 'Existen movimientos posteriores: recalcular antes de restituir'; END IF;
    SELECT lo.id INTO STRICT v_tipo_ajuste FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='TipoMovInvUnificado' AND lo.nombre='AJUSTE' AND lo.estado=1;
    SELECT lo.id INTO STRICT v_tipo_retorno FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='TipoMovInvUnificado' AND lo.nombre='RETORNO_LIMA' AND lo.estado=1;
    FOR r IN SELECT * FROM inv_movimiento WHERE id BETWEEN 971 AND 1018 ORDER BY id LOOP
        IF r.naturaleza='PRODUCTO' THEN
            IF r.stock_anterior-r.stock_nuevo IS DISTINCT FROM r.cantidad OR r.cantidad<=0 THEN
                RAISE EXCEPTION 'Movimiento % no es el débito esperado',r.id;
            END IF;
            SELECT * INTO STRICT v_stock FROM pro_stock
            WHERE id_producto=r.id_producto AND id_almacen=r.id_almacen_origen AND estado=1 FOR UPDATE;
            UPDATE pro_stock SET stock=stock+r.cantidad,
                fecha_modificacion=NOW(),id_usuario_modificacion=v_usuario WHERE id=v_stock.id;
            INSERT INTO inv_movimiento(fecha,id_tipo_movimiento,naturaleza,id_producto,cantidad,
                id_unidad_medida,id_almacen_origen,id_documento_origen,id_tipo_documento_origen,
                id_documento_detalle,id_movimiento_padre,stock_anterior,stock_nuevo,glosa,
                id_usuario_creacion,id_usuario_modificacion)
            VALUES(NOW(),v_tipo_ajuste,'PRODUCTO',r.id_producto,r.cantidad,
                r.id_unidad_medida,r.id_almacen_origen,1,r.id_tipo_documento_origen,
                r.id_documento_detalle,r.id,v_stock.stock,v_stock.stock+r.cantidad,
                format('Restitución ruta histórica #1: compensa movimiento %s; registro sin efecto en inventario',r.id),
                v_usuario,v_usuario);
        ELSE
            SELECT * INTO STRICT v_balon FROM bal_balon WHERE id=r.id_balon AND estado=1 FOR UPDATE;
            IF v_balon.id_estado_balon IS DISTINCT FROM r.id_estado_balon_snapshot
               OR v_balon.id_almacen IS NOT NULL THEN
                RAISE EXCEPTION 'Cilindro % cambió desde la salida',r.id_balon;
            END IF;
            UPDATE bal_balon SET id_estado_balon=r.id_estado_balon_anterior,
                id_almacen=r.id_almacen_anterior,id_cliente_ubicacion=r.id_cliente_ubicacion_anterior,
                fecha_modificacion=NOW(),id_usuario_modificacion=v_usuario WHERE id=r.id_balon;
            INSERT INTO inv_movimiento(fecha,id_tipo_movimiento,naturaleza,id_balon,cantidad,
                id_almacen_destino,id_documento_origen,id_tipo_documento_origen,id_movimiento_padre,
                id_estado_balon_snapshot,id_estado_balon_anterior,id_almacen_anterior,
                id_cliente_ubicacion_anterior,glosa,id_usuario_creacion,id_usuario_modificacion)
            VALUES(NOW(),v_tipo_retorno,'BALON',r.id_balon,1,
                r.id_almacen_anterior,1,r.id_tipo_documento_origen,r.id,
                r.id_estado_balon_anterior,v_balon.id_estado_balon,v_balon.id_almacen,
                v_balon.id_cliente_ubicacion,
                format('Restitución ruta histórica #1: compensa movimiento %s; no representa retorno físico',r.id),
                v_usuario,v_usuario);
        END IF;
    END LOOP;
END;
$correccion$;
