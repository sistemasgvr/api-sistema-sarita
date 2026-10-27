-- Run ONLY against the restored Docker snapshot using vsd-local.js.
-- Requiere aplicado database_sql/migraciones/garantias-editar.sql (ven_actualizar_garantia y detalle ampliado).
-- Todo el fixture y las operaciones se revierten (ROLLBACK al final).
BEGIN;
CREATE TEMP TABLE garantia_results(label text);
CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO garantia_results VALUES(label);
END $$;

CREATE FUNCTION pg_temp.medio_total(p_totales json, p_medio integer) RETURNS numeric LANGUAGE sql AS $$
  SELECT COALESCE(SUM((r->>'garantiasCobro')::numeric), 0)
  FROM json_array_elements(p_totales->'porMedio') r
  WHERE (r->>'idMedioPago')::integer = p_medio
$$;

DO $$
DECLARE
  v_usuario integer;
  v_sucursal integer;
  v_cliente integer;
  v_prestamo integer;
  v_fecha date := CURRENT_DATE + 40;
  v_fecha_cerrada date := CURRENT_DATE + 41;
  v_fecha_sin_caja date := CURRENT_DATE + 42;
  v_cuenta integer;
  v_abierta integer;
  v_yape integer;
  v_efectivo integer;
  v_cobro integer;
  v_devolucion integer;
  v_activa integer;
  v_sesion integer;
  v_garantia integer;
  v_mov integer;
  v_antes json;
  v_despues json;
  v_result json;
BEGIN
  SELECT min(id) INTO v_usuario FROM auth_usuarios WHERE estado = true;
  SELECT min(id) INTO v_sucursal FROM gen_sucursal;
  SELECT min(id) INTO v_cliente FROM cli_clientes WHERE estado = 1;
  SELECT min(id) INTO v_prestamo FROM bal_prestamo;
  SELECT lo.id INTO v_abierta FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA' LIMIT 1;
  SELECT lo.id INTO v_yape FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MedioPago' AND lo.nombre = 'YAPE' LIMIT 1;
  SELECT lo.id INTO v_efectivo FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MedioPago' AND lo.nombre = 'EFECTIVO' LIMIT 1;
  SELECT lo.id INTO v_cobro FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' LIMIT 1;
  SELECT lo.id INTO v_devolucion FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'DEVOLUCION' LIMIT 1;
  SELECT lo.id INTO v_activa FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' LIMIT 1;
  PERFORM pg_temp.ok(v_usuario IS NOT NULL AND v_sucursal IS NOT NULL AND v_cliente IS NOT NULL
                     AND v_prestamo IS NOT NULL AND v_yape IS NOT NULL AND v_efectivo IS NOT NULL
                     AND v_cobro IS NOT NULL AND v_devolucion IS NOT NULL AND v_activa IS NOT NULL,
                     'Fixture: usuario, sucursal, cliente, préstamo y catálogos');

  UPDATE fin_caja_sesion SET estado = 0
  WHERE estado = 1 AND COALESCE(id_sucursal, 0) = v_sucursal
    AND (fecha IN (v_fecha, v_fecha_cerrada, v_fecha_sin_caja) OR id_estado = v_abierta);

  v_result := fin_abrir_caja_sesion(v_fecha, 0, v_sucursal, 'test garantías', v_usuario, NULL::integer);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'abrir caja del día de prueba');

  -- Cuenta válida para YAPE (NULL si YAPE no la exige)
  IF fin_validar_cuenta_medio_pago(v_yape, NULL) IS NOT NULL THEN
    SELECT cb.id INTO v_cuenta FROM gen_cuenta_bancaria cb
    WHERE fin_validar_cuenta_medio_pago(v_yape, cb.id) IS NULL ORDER BY cb.id LIMIT 1;
    PERFORM pg_temp.ok(v_cuenta IS NOT NULL, 'Fixture: cuenta válida para YAPE');
  END IF;

  -- Garantía ligada a préstamo: cabecera SIN medio y cobro por YAPE (el cobro es la verdad)
  INSERT INTO ven_garantia (id_cliente, id_prestamo, fecha_registro, monto_cobrado, monto_devuelto, monto_saldo,
                            id_estado, id_medio_pago, id_usuario_creacion, id_usuario_modificacion)
  VALUES (v_cliente, v_prestamo, v_fecha, 80, 0, 80, v_activa, NULL, v_usuario, v_usuario)
  RETURNING id INTO v_garantia;
  INSERT INTO ven_garantia_movimiento (id_garantia, id_tipo_movimiento, fecha, monto, observacion, id_sucursal,
                                       id_medio_pago, id_cuenta_bancaria, numero_operacion,
                                       id_usuario_creacion, id_usuario_modificacion)
  VALUES (v_garantia, v_cobro, v_fecha, 80, 'Cobro test', v_sucursal, v_yape, v_cuenta, 'OP-1', v_usuario, v_usuario)
  RETURNING id INTO v_mov;

  v_result := ven_obtener_garantia(v_garantia);
  PERFORM pg_temp.ok((v_result->'registro'->>'cobro_id_medio_pago')::integer = v_yape
                     AND (v_result->'registro'->>'cobro_fecha')::date = v_fecha
                     AND v_result->'registro'->>'numero_operacion' = 'OP-1',
                     'detalle: valores efectivos del cobro');

  -- Solo observación: no toca el cobro
  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, NULL, NULL, NULL, NULL, 'solo nota', v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'editar solo observación');
  PERFORM pg_temp.ok(json_typeof(v_result->'avisos') = 'array' AND json_array_length(v_result->'avisos') = 0,
                     'devuelve avisos[] vacío');
  PERFORM pg_temp.ok((SELECT id_medio_pago = v_yape AND id_cuenta_bancaria IS NOT DISTINCT FROM v_cuenta
                             AND numero_operacion = 'OP-1' AND fecha = v_fecha AND monto = 80
                      FROM ven_garantia_movimiento WHERE id = v_mov), 'observación no altera el cobro');

  -- Nº de operación con el mismo medio
  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, NULL, NULL, 'OP-777', NULL, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'editar nº de operación');
  PERFORM pg_temp.ok((SELECT numero_operacion FROM ven_garantia_movimiento WHERE id = v_mov) = 'OP-777',
                     'nº de operación guardado en el COBRO');
  PERFORM pg_temp.ok(v_result->'registro'->>'numero_operacion' = 'OP-777', 'detalle devuelve numero_operacion');

  v_antes := fin_caja_calcular_totales(v_fecha, v_sucursal);

  -- YAPE -> EFECTIVO: limpia cuenta y nº de operación
  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, v_efectivo, NULL, NULL, NULL, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'editar garantía de préstamo sin error');
  PERFORM pg_temp.ok((SELECT id_medio_pago FROM ven_garantia_movimiento WHERE id = v_mov) = v_efectivo,
                     'el COBRO pasa a EFECTIVO');
  PERFORM pg_temp.ok((SELECT id_cuenta_bancaria IS NULL AND numero_operacion IS NULL
                      FROM ven_garantia_movimiento WHERE id = v_mov), 'EFECTIVO sin cuenta ni nº de operación');
  PERFORM pg_temp.ok((SELECT id_medio_pago FROM ven_garantia WHERE id = v_garantia) = v_efectivo,
                     'cabecera con el nuevo medio');
  PERFORM pg_temp.ok(v_result->'registro'->'movimientos'->0->>'medio_pago' = 'EFECTIVO', 'detalle: medio por movimiento');

  v_despues := fin_caja_calcular_totales(v_fecha, v_sucursal);
  PERFORM pg_temp.ok(pg_temp.medio_total(v_despues, v_yape) = pg_temp.medio_total(v_antes, v_yape) - 80,
                     'caja: YAPE pierde los 80');
  PERFORM pg_temp.ok(pg_temp.medio_total(v_despues, v_efectivo) = pg_temp.medio_total(v_antes, v_efectivo) + 80,
                     'caja: EFECTIVO gana los 80');

  -- Monto por debajo de lo devuelto
  INSERT INTO ven_garantia_movimiento (id_garantia, id_tipo_movimiento, fecha, monto, observacion,
                                       id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion)
  VALUES (v_garantia, v_devolucion, v_fecha, 30, 'Devolución test', v_sucursal, v_efectivo, v_usuario, v_usuario);
  UPDATE ven_garantia SET monto_devuelto = 30, monto_saldo = 50 WHERE id = v_garantia;

  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, NULL, NULL, NULL, 20, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NOT NULL, 'monto menor a lo devuelto: rechazado');
  PERFORM pg_temp.ok(v_result->>'error' LIKE '%(20.00)%(30.00)%', 'error con montos a 2 decimales');
  PERFORM pg_temp.ok((SELECT monto_cobrado FROM ven_garantia WHERE id = v_garantia) = 80, 'monto intacto tras rechazo');

  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, NULL, NULL, NULL, 30, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'monto igual a lo devuelto: permitido');
  PERFORM pg_temp.ok(v_result->'registro'->>'nombre_estado' = 'DEVUELTA'
                     AND (v_result->'registro'->>'monto_saldo')::numeric = 0, 'saldo 0 y estado DEVUELTA');
  PERFORM pg_temp.ok((SELECT monto FROM ven_garantia_movimiento WHERE id = v_mov) = 30, 'monto del COBRO actualizado');

  -- Caja cerrada: avisa pero guarda (se cierra antes la del primer día para poder abrir otra)
  v_sesion := (SELECT id FROM fin_caja_sesion WHERE estado = 1 AND fecha = v_fecha
               AND COALESCE(id_sucursal, 0) = v_sucursal ORDER BY id DESC LIMIT 1);
  PERFORM fin_cerrar_caja_sesion(v_sesion, 0, 'cierre día 1', v_usuario);
  v_result := fin_abrir_caja_sesion(v_fecha_cerrada, 0, v_sucursal, 'test cerrada', v_usuario, NULL::integer);
  v_sesion := (v_result->'registro'->>'id')::integer;
  PERFORM pg_temp.ok(v_sesion IS NOT NULL, 'abrir caja a cerrar');
  v_result := fin_cerrar_caja_sesion(v_sesion, 0, 'cierre test', v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'cerrar caja de prueba');

  v_result := ven_actualizar_garantia(v_garantia, v_fecha_cerrada, NULL, NULL, NULL, NULL, 50, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'caja cerrada no bloquea');
  PERFORM pg_temp.ok(EXISTS (
      SELECT 1 FROM json_array_elements_text(v_result->'avisos') a
      WHERE a LIKE '%' || to_char(v_fecha_cerrada, 'DD/MM/YYYY') || '%cerrada%'
  ), 'aviso de caja cerrada');
  PERFORM pg_temp.ok((SELECT fecha FROM ven_garantia_movimiento WHERE id = v_mov) = v_fecha_cerrada
                     AND (SELECT fecha_registro FROM ven_garantia WHERE id = v_garantia) = v_fecha_cerrada,
                     'fecha guardada en cabecera y COBRO');
  PERFORM pg_temp.ok(v_result->'registro'->>'nombre_estado' = 'PARCIAL', 'saldo 20 vuelve a PARCIAL');

  -- Fecha sin caja: avisa y guarda
  v_result := ven_actualizar_garantia(v_garantia, v_fecha_sin_caja, NULL, NULL, NULL, NULL, NULL, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'fecha sin caja no bloquea');
  PERFORM pg_temp.ok(EXISTS (
      SELECT 1 FROM json_array_elements_text(v_result->'avisos') a
      WHERE a = 'No hay caja para el ' || to_char(v_fecha_sin_caja, 'DD/MM/YYYY') || ': el cobro se contará cuando se abra'
  ), 'aviso de fecha sin caja');

  -- Dos cobros activos: solo cliente y observación
  INSERT INTO ven_garantia_movimiento (id_garantia, id_tipo_movimiento, fecha, monto, observacion,
                                       id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion)
  VALUES (v_garantia, v_cobro, v_fecha_sin_caja, 5, 'Segundo cobro test', v_sucursal, v_efectivo, v_usuario, v_usuario);
  v_result := ven_actualizar_garantia(v_garantia, v_fecha, NULL, NULL, NULL, NULL, NULL, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' LIKE '%2 cobros%', 'dos cobros: cambio de fecha rechazado');
  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, v_yape, v_cuenta, 'OP-2', NULL, NULL, v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' LIKE '%2 cobros%', 'dos cobros: cambio de medio rechazado');
  v_result := ven_actualizar_garantia(v_garantia, NULL, NULL, NULL, NULL, NULL, NULL, 'nota final', v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL AND v_result->'registro'->>'observacion' = 'nota final',
                     'dos cobros: observación permitida');
END $$;

SELECT 'PASS '||label FROM garantia_results;
SELECT 'TOTAL '||count(*) FROM garantia_results;
ROLLBACK;
