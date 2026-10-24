-- Run ONLY against the restored Docker snapshot using vsd-local.js.
-- Every fixture and every business operation is rolled back.
BEGIN;
CREATE TEMP TABLE vsd_results(label text);
CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO vsd_results VALUES(label);
END $$;
CREATE FUNCTION pg_temp.state() RETURNS text LANGUAGE sql AS $$
  SELECT md5(string_agg(x, E'\n' ORDER BY x)) FROM (
    SELECT 'stock'||row_to_json(t)::text x FROM pro_stock t
    UNION ALL SELECT 'balon'||row_to_json(t)::text FROM bal_balon t
    UNION ALL SELECT 'mov'||row_to_json(t)::text FROM inv_movimiento t
    UNION ALL SELECT 'venta'||row_to_json(t)::text FROM ven_comprobante t
    UNION ALL SELECT 'detalle'||row_to_json(t)::text FROM ven_comprobante_detalle t
    UNION ALL SELECT 'prestamo'||row_to_json(t)::text FROM bal_prestamo t
    UNION ALL SELECT 'pd'||row_to_json(t)::text FROM bal_prestamo_detalle t
    UNION ALL SELECT 'garantia'||row_to_json(t)::text FROM ven_garantia t
    UNION ALL SELECT 'cuenta'||row_to_json(t)::text FROM fin_cuenta t
    UNION ALL SELECT 'pago'||row_to_json(t)::text FROM ven_comprobante_pago t
    UNION ALL SELECT 'actividad'||row_to_json(t)::text FROM age_actividad_item t
    UNION ALL SELECT 'audit'||row_to_json(t)::text FROM ven_vsd_operacion t
  ) s
$$;
CREATE FUNCTION pg_temp.reject(command text, pattern text, label text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE before_hash text := pg_temp.state(); message text; rejected boolean := false;
BEGIN
  BEGIN EXECUTE command;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS message = MESSAGE_TEXT;
    IF message NOT ILIKE '%'||pattern||'%' THEN RAISE EXCEPTION 'Unexpected error for %: %',label,message; END IF;
    rejected := true;
  END;
  PERFORM pg_temp.ok(rejected,label);
  PERFORM pg_temp.ok(before_hash=pg_temp.state(),label||' / rollback completo');
END $$;

DO $$
DECLARE usuario integer; version text; details json; result json; old_detail integer; old_ball integer;
  fixture integer := -920001; almacen integer; producto integer; stock_before numeric;
BEGIN
  SELECT min(id) INTO usuario FROM auth_usuarios WHERE estado=true;
  SELECT xmin::text INTO version FROM ven_comprobante WHERE id=141;
  SELECT id,id_balon INTO old_detail,old_ball FROM ven_comprobante_detalle WHERE id_comprobante=141 AND estado=1 LIMIT 1;
  PERFORM pg_temp.ok(old_ball IS NOT NULL,'Fixture real: venta con balón y préstamo');
  result := ven_actualizar_comprobante(p_id=>141,p_observaciones=>'Prueba local de corrección',
      p_id_usuario_auditoria=>usuario,p_motivo_correccion=>'Corrección documentada en prueba',p_version_esperada=>version);
  PERFORM pg_temp.ok(result->>'error' IS NULL AND result->'registro' IS NOT NULL,'Corrección de observaciones');
  SELECT json_agg(d ORDER BY item) INTO details FROM ven_comprobante_detalle d WHERE id_comprobante=141 AND estado=1;
  result := ven_actualizar_comprobante(p_id=>141,p_detalles=>details,p_id_usuario_auditoria=>usuario,
      p_motivo_correccion=>'Guardar el mismo detalle vinculado',p_version_esperada=>(SELECT xmin::text FROM ven_comprobante WHERE id=141));
  PERFORM pg_temp.ok(result->>'error' IS NULL AND EXISTS(SELECT 1 FROM ven_comprobante_detalle WHERE id=old_detail AND estado=1 AND id_balon=old_ball),
      'Guardar conserva id de detalle y referencia del balón');
  SELECT xmin::text INTO version FROM ven_comprobante WHERE id=141;
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>141,p_detalles=>%L::json,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',
      jsonb_set(details::jsonb,'{0,cantidad}','9999'::jsonb)::text,usuario,'Cambiar cantidades vinculadas',version), 'vinculadas','Bloqueo de cantidades con préstamo');
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>141,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',usuario,'Versión obsoleta de la venta','0'),
      'cambió','Bloqueo de edición concurrente obsoleta');
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>141,p_id_usuario_auditoria=>%s,p_version_esperada=>%L)',usuario,version),
      'motivo','Motivo obligatorio');
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>141,p_id_cliente=>1,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',usuario,'Cambio del cliente vinculado',version),
      'vinculadas','No reasigna la custodia a otro cliente');

  -- Isolated ordinary-product sale, copied from a real sale without its payments or CxC.
  INSERT INTO ven_comprobante SELECT (jsonb_populate_record(NULL::ven_comprobante,to_jsonb(c)||
      jsonb_build_object('id',fixture,'serie','VSD99','numero','TEST-CORR','id_condicion_pago',null,'id_medio_pago',null))).*
      FROM ven_comprobante c WHERE id=140;
  INSERT INTO ven_comprobante_detalle SELECT (jsonb_populate_record(NULL::ven_comprobante_detalle,to_jsonb(d)||
      jsonb_build_object('id',fixture,'id_comprobante',fixture,'id_balon',null))).*
      FROM ven_comprobante_detalle d WHERE id_comprobante=140 AND estado=1 LIMIT 1;
  SELECT id_almacen INTO almacen FROM ven_comprobante WHERE id=fixture;
  SELECT id_producto INTO producto FROM ven_comprobante_detalle WHERE id=fixture;
  UPDATE pro_stock SET stock=100 WHERE id_producto=producto AND id_almacen=almacen AND estado=1;
  SELECT json_agg(to_jsonb(d)||jsonb_build_object('cantidad',d.cantidad+1) ORDER BY item) INTO details FROM ven_comprobante_detalle d WHERE id_comprobante=fixture AND estado=1;
  result := ven_actualizar_comprobante(p_id=>fixture,p_detalles=>details,p_id_usuario_auditoria=>usuario,
      p_motivo_correccion=>'Corrección de una cantidad de producto',p_version_esperada=>(SELECT xmin::text FROM ven_comprobante WHERE id=fixture));
  PERFORM pg_temp.ok(result->>'error' IS NULL AND (SELECT stock=99 FROM pro_stock WHERE id_producto=producto AND id_almacen=almacen AND estado=1),'Aumentar cantidad descuenta solo la diferencia');
  SELECT json_agg(to_jsonb(d)||jsonb_build_object('cantidad',d.cantidad-1) ORDER BY item) INTO details FROM ven_comprobante_detalle d WHERE id_comprobante=fixture AND estado=1;
  result := ven_actualizar_comprobante(p_id=>fixture,p_detalles=>details,p_id_usuario_auditoria=>usuario,
      p_motivo_correccion=>'Reducir la cantidad al valor original',p_version_esperada=>(SELECT xmin::text FROM ven_comprobante WHERE id=fixture));
  PERFORM pg_temp.ok(result->>'error' IS NULL AND (SELECT stock=100 FROM pro_stock WHERE id_producto=producto AND id_almacen=almacen AND estado=1),'Reducir cantidad restaura solo la diferencia');
  SELECT json_agg(to_jsonb(d)||jsonb_build_object('cantidad',100000) ORDER BY item) INTO details FROM ven_comprobante_detalle d WHERE id_comprobante=fixture AND estado=1;
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_detalles=>%L::json,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,details::text,usuario,'Intento con stock insuficiente',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
      'insuficiente','Stock insuficiente en corrección');
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_id_almacen=>%s,p_detalles=>%L::json,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,
      (SELECT id FROM gen_almacen WHERE estado=1 AND id<>almacen LIMIT 1),details::text,usuario,'Fallo después de reingresar al almacén anterior',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
      'insuficiente','Fallo después de reponer stock antiguo revierte todo');
  UPDATE pro_producto SET estado=0 WHERE id=producto;
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_detalles=>%L::json,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,details::text,usuario,'Intento con producto inactivo',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
      'inactivo','No corrige hacia un producto inactivo');
  UPDATE pro_producto SET estado=1 WHERE id=producto;
  PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_detalles=>%L::json,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,
      jsonb_set(details::jsonb,'{0,precio_unitario}','-1')::text,usuario,'Precio negativo no permitido',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
      'inválido','No acepta precios negativos');
END $$;

DO $$
DECLARE usuario integer; payload jsonb; result json; retry json; nuevo integer := -920003; tercero integer := -920004;
  old_pd integer; loan integer; stock_before numeric; money_before text;
BEGIN
  SELECT min(id) INTO usuario FROM auth_usuarios WHERE estado=true;
  INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object(
      'id',nuevo,'codigo_balon','LOCAL-VSD-REEMPLAZO','id_almacen',2,'id_cliente_ubicacion',null,
      'fecha_proxima_prueba_hidrostatica',CURRENT_DATE+365,
      'id_estado_balon',(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoBalon' AND lo.nombre='DISPONIBLE' LIMIT 1)))).*
    FROM bal_balon b WHERE id=638;
  INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object('id',tercero,'codigo_balon','LOCAL-VSD-TERCERO'))).* FROM bal_balon b WHERE id=nuevo;
  UPDATE pro_stock SET stock=100 WHERE id_producto=9 AND id_almacen=2 AND estado=1;
  UPDATE bal_balon SET fecha_proxima_prueba_hidrostatica=CURRENT_DATE+365 WHERE id=638;
  SELECT pd.id,pd.id_prestamo INTO old_pd,loan FROM bal_prestamo_detalle pd JOIN bal_prestamo p ON p.id=pd.id_prestamo
    WHERE p.id_comprobante_venta=141 AND pd.id_balon=638 AND pd.estado=1 AND pd.fecha_devolucion IS NULL;
  payload := jsonb_build_object('tipoOperacion','CAMBIO','solicitud','71722ec7-71ce-4400-96ee-f23d46064901',
      'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=141), 'idBalonActual',638,'idBalonNuevo',nuevo,
      'idAlmacen',2,'cantidadGasDevuelta',0,'cantidadGasSalida',6,'condicionDevolucion','DISPONIBLE','motivo','Cambio local de balón con préstamo');
  INSERT INTO ven_comprobante SELECT (jsonb_populate_record(NULL::ven_comprobante,to_jsonb(c)||jsonb_build_object(
      'id',-920050,'serie','VSD98','numero','TEST-DERIVADO','id_comprobante_origen',141))).* FROM ven_comprobante c WHERE id=141;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'derivado','No cambia una venta con documento derivado');
  DELETE FROM ven_comprobante WHERE id=-920050;
  UPDATE bal_balon SET id_estado_balon=(SELECT id_estado_balon FROM bal_balon WHERE id=638) WHERE id=nuevo;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'disponible','No entrega un balón ya comprometido');
  UPDATE bal_balon SET id_estado_balon=(SELECT id_estado_balon FROM bal_balon WHERE id=tercero) WHERE id=nuevo;
  INSERT INTO bal_baja_balon(id,id_balon,id_motivo_baja,id_usuario_solicita,estado_aprobacion)
      VALUES(-920080,nuevo,(SELECT min(id) FROM gen_lista_opciones),usuario,'PENDIENTE');
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'baja o mantenimiento','No entrega un balón con baja pendiente');
  DELETE FROM bal_baja_balon WHERE id=-920080;
  INSERT INTO bal_mantenimiento(id,id_balon,fecha_ingreso) VALUES(-920081,nuevo,CURRENT_DATE);
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'baja o mantenimiento','No entrega un balón con mantenimiento abierto');
  DELETE FROM bal_mantenimiento WHERE id=-920081;
  INSERT INTO ven_garantia SELECT (jsonb_populate_record(NULL::ven_garantia,to_jsonb(g)||jsonb_build_object(
      'id',-920010,'id_cliente',75,'id_prestamo',loan,'id_prestamo_detalle',old_pd,'id_alquiler',null))).* FROM ven_garantia g WHERE estado=1 LIMIT 1;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{cantidadGasSalida}','5')::text,usuario),'cantidad de salida','No cambia la capacidad comercial sin nueva venta');
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{idAlmacen}','1')::text,usuario),'disponible','No entrega de otro almacén');
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{idBalonNuevo}','9999999')::text,usuario),'no existe','No entrega un balón inexistente');
  UPDATE bal_balon SET id_propietario=(SELECT id FROM gen_lista_opciones WHERE nombre='CLIENTE' AND estado=1 LIMIT 1) WHERE id=nuevo;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'propietario','No intercambia propiedad ajena');
  UPDATE bal_balon SET id_propietario=(SELECT id_propietario FROM bal_balon WHERE id=638),fecha_proxima_prueba_hidrostatica=NULL WHERE id=nuevo;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'hidrostática','Rechaza PH no registrada');
  UPDATE bal_balon SET fecha_proxima_prueba_hidrostatica=CURRENT_DATE+365 WHERE id=nuevo;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{cantidadGasDevuelta}','7')::text,usuario),'remanente','No devuelve más gas del vendido');
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{idBalonNuevo}','638')::text,usuario),'distintos','No cambia por el mismo balón');
  UPDATE bal_balon SET fecha_proxima_prueba_hidrostatica=CURRENT_DATE-1 WHERE id=nuevo;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'hidrostática','Rechaza PH vencida');
  UPDATE bal_balon SET fecha_proxima_prueba_hidrostatica=CURRENT_DATE+365 WHERE id=nuevo;
  SELECT md5(string_agg(row_to_json(p)::text,'' ORDER BY p.id)) INTO money_before FROM ven_comprobante_pago p WHERE id_comprobante=141;
  result := ven_cambiar_balon_vsd(141,payload,usuario);
  PERFORM pg_temp.ok(result->'registro'->>'id' IS NOT NULL,'Cambio real con préstamo y recojo pendiente');
  PERFORM pg_temp.ok((SELECT stock=94 FROM pro_stock WHERE id_producto=9 AND id_almacen=2 AND estado=1),'Balón vacío no repone gas; reemplazo descuenta 6');
  PERFORM pg_temp.ok((SELECT b.id_almacen=2 AND b.id_cliente_ubicacion IS NULL AND eb.nombre='DISPONIBLE' FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=638),'Balón devuelto queda en almacén y sin cliente');
  PERFORM pg_temp.ok((SELECT b.id_almacen IS NULL AND b.id_cliente_ubicacion=75 AND eb.nombre='PRESTADO_CLIENTE' FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=nuevo),'Reemplazo queda prestado al cliente correcto');
  PERFORM pg_temp.ok((SELECT fecha_devolucion IS NOT NULL FROM bal_prestamo_detalle WHERE id=old_pd) AND EXISTS(SELECT 1 FROM bal_prestamo_detalle WHERE id_prestamo=loan AND id_balon=nuevo AND estado=1 AND fecha_devolucion IS NULL),'Préstamo conserva el devuelto y añade reemplazo');
  PERFORM pg_temp.ok(EXISTS(SELECT 1 FROM ven_garantia g JOIN bal_prestamo_detalle pd ON pd.id=g.id_prestamo_detalle
      WHERE g.id=-920010 AND pd.id_balon=nuevo AND pd.id_prestamo=loan),'Garantía conserva contrato y se vincula al reemplazo');
  PERFORM pg_temp.ok(NOT EXISTS(SELECT 1 FROM age_actividad_item i JOIN age_actividad a ON a.id=i.id_actividad
      JOIN gen_lista_opciones ea ON ea.id=a.id_estado_actividad WHERE i.id_prestamo_detalle=old_pd AND i.estado=1 AND a.estado=1 AND ea.nombre='PENDIENTE'),'Recojo pendiente apunta al reemplazo');
  PERFORM pg_temp.ok(EXISTS(SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante=141 AND id_balon=638 AND estado=1),'Venta original conserva el balón histórico');
  PERFORM pg_temp.ok(money_before IS NOT DISTINCT FROM (SELECT md5(string_agg(row_to_json(p)::text,'' ORDER BY p.id)) FROM ven_comprobante_pago p WHERE id_comprobante=141),'Cambio conserva cobros originales');
  retry := ven_cambiar_balon_vsd(141,payload,usuario);
  PERFORM pg_temp.ok(retry->'registro'->>'id'=result->'registro'->>'id' AND (SELECT stock=94 FROM pro_stock WHERE id_producto=9 AND id_almacen=2 AND estado=1),'Reintento idempotente no duplica salida ni gas');
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',jsonb_set(payload,'{motivo}','"Otro motivo con igual solicitud"')::text,usuario),'solicitud','No reutiliza solicitud con otros datos');
  PERFORM pg_temp.ok((ven_eliminar_comprobante(141,usuario)->>'eliminado')::boolean=false,'No elimina venta con cambios físicos');

  payload := payload || jsonb_build_object('solicitud','71722ec7-71ce-4400-96ee-f23d46064902','idBalonActual',nuevo,'idBalonNuevo',tercero,
      'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=141));
  UPDATE pro_stock SET stock=0 WHERE id_producto=9 AND id_almacen=2 AND estado=1;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(141,%L::jsonb,%s)',payload::text,usuario),'insuficiente','Sin stock deshace devolución, préstamo y auditoría');
  UPDATE pro_stock SET stock=94 WHERE id_producto=9 AND id_almacen=2 AND estado=1;
  payload := payload || jsonb_build_object('cantidadGasDevuelta',6);
  result := ven_cambiar_balon_vsd(141,payload,usuario);
  PERFORM pg_temp.ok((SELECT stock=94 FROM pro_stock WHERE id_producto=9 AND id_almacen=2 AND estado=1),'Devolución utilizable de 6 y salida de 6 tiene saldo neto cero');
END $$;

DO $$
DECLARE usuario integer; payload jsonb; result json; fixture integer := -920020;
  old_id integer := -920021; new_id integer := -920022; stock_hash text;
BEGIN
  SELECT min(id) INTO usuario FROM auth_usuarios WHERE estado=true;
  INSERT INTO ven_comprobante SELECT (jsonb_populate_record(NULL::ven_comprobante,to_jsonb(c)||jsonb_build_object(
      'id',fixture,'serie','VSD99','numero','TEST-RESERVA','id_condicion_pago',null,'id_medio_pago',null))).* FROM ven_comprobante c WHERE id=134;
  INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object('id',old_id,
      'codigo_balon','LOCAL-VSD-RESERVADO','id_almacen',2,'id_cliente_ubicacion',null,'fecha_proxima_prueba_hidrostatica',CURRENT_DATE+365,
      'id_estado_balon',(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoBalon' AND lo.nombre='PENDIENTE_ENVIO' LIMIT 1)))).* FROM bal_balon b WHERE id=307;
  INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object('id',new_id,
      'codigo_balon','LOCAL-VSD-RESERVA-NUEVO','id_estado_balon',(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoBalon' AND lo.nombre='DISPONIBLE' LIMIT 1)))).* FROM bal_balon b WHERE id=old_id;
  INSERT INTO ven_comprobante_detalle SELECT (jsonb_populate_record(NULL::ven_comprobante_detalle,to_jsonb(d)||jsonb_build_object(
      'id',fixture,'id_comprobante',fixture,'id_balon',old_id))).* FROM ven_comprobante_detalle d WHERE id_comprobante=134 AND estado=1 LIMIT 1;
  UPDATE ven_comprobante_detalle SET cantidad=4 WHERE id=fixture;
  PERFORM pg_temp.ok(ven_cantidad_gas_balon_vsd(fixture,old_id)=4,'Una carga parcial conserva la cantidad de su balón');
  INSERT INTO ven_comprobante_detalle SELECT (jsonb_populate_record(NULL::ven_comprobante_detalle,to_jsonb(d)||jsonb_build_object(
      'id',-920070,'item',2,'cantidad',20,'id_balon',null))).* FROM ven_comprobante_detalle d WHERE id=fixture;
  PERFORM pg_temp.ok(ven_cantidad_gas_balon_vsd(fixture,old_id)=4,'No toma la cantidad mayor de otra línea del mismo gas');
  PERFORM pg_temp.ok(ven_cantidad_gas_balon_vsd(fixture,new_id) IS NULL,'Sin vínculo inequívoco no adivina la cantidad del balón');
  DELETE FROM ven_comprobante_detalle WHERE id=-920070;
  UPDATE ven_comprobante_detalle SET cantidad=10 WHERE id=fixture;
  payload := jsonb_build_object('tipoOperacion','CORRECCION_RESERVA','solicitud','71722ec7-71ce-4400-96ee-f23d46064903',
      'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture),'idBalonActual',old_id,'idBalonNuevo',new_id,
      'idAlmacen',2,'cantidadGasDevuelta',0,'cantidadGasSalida',0,'condicionDevolucion','DISPONIBLE','motivo','Corregir selección antes del despacho');
  SELECT md5(string_agg(row_to_json(s)::text,'' ORDER BY s.id)) INTO stock_hash FROM pro_stock s;
  PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(%s,%L::jsonb,%s)',fixture,jsonb_set(payload,'{cantidadGasSalida}','10')::text,usuario),'no mueve gas','Reserva no permite una segunda salida de gas');
  result := ven_cambiar_balon_vsd(fixture,payload,usuario);
  PERFORM pg_temp.ok(result->'registro'->>'id' IS NOT NULL,'Corrige balón reservado antes de despacho');
  PERFORM pg_temp.ok(stock_hash=(SELECT md5(string_agg(row_to_json(s)::text,'' ORDER BY s.id)) FROM pro_stock s),'Corrección de reserva no altera ninguna fila de stock');
  PERFORM pg_temp.ok((SELECT eb.nombre='DISPONIBLE' AND b.id_almacen=2 AND b.id_cliente_ubicacion IS NULL FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=old_id),'Libera reserva anterior');
  PERFORM pg_temp.ok((SELECT eb.nombre='PENDIENTE_ENVIO' AND b.id_almacen=2 FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=new_id),'Reserva el reemplazo sin entregarlo');
  PERFORM pg_temp.ok(EXISTS(SELECT 1 FROM ven_comprobante_detalle WHERE id=fixture AND id_balon=new_id AND estado=1),'Despacho leerá el balón corregido, con el mismo detalle');
  result := ven_confirmar_entrega_mostrador(fixture,usuario);
  PERFORM pg_temp.ok(result->>'error' IS NULL AND (SELECT eb.nombre='EN_PODER_CLIENTE' AND b.id_cliente_ubicacion=258 FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=new_id),'Entrega posterior usa el nuevo balón');
  UPDATE pro_stock SET stock=100 WHERE id_producto=10 AND id_almacen=2 AND estado=1;
  payload := payload || jsonb_build_object('tipoOperacion','CAMBIO','solicitud','71722ec7-71ce-4400-96ee-f23d46064904',
      'idBalonActual',new_id,'idBalonNuevo',old_id,'cantidadGasSalida',10,'cantidadGasDevuelta',0,'condicionDevolucion','EN_MANTENIMIENTO',
      'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture));
  result := ven_cambiar_balon_vsd(fixture,payload,usuario);
  PERFORM pg_temp.ok(result->'registro'->>'id' IS NOT NULL,'Permite cambio físico después de corregir y entregar una reserva');
  PERFORM pg_temp.ok((SELECT eb.nombre='EN_MANTENIMIENTO' AND b.id_almacen=2 AND b.id_cliente_ubicacion IS NULL FROM bal_balon b JOIN gen_lista_opciones eb ON eb.id=b.id_estado_balon WHERE b.id=new_id),'Balón defectuoso queda en mantenimiento y sin cliente');
  PERFORM pg_temp.ok((SELECT stock=90 FROM pro_stock WHERE id_producto=10 AND id_almacen=2 AND estado=1),'Balón para mantenimiento no repone gas');
END $$;

DO $$
DECLARE codigo text; n integer:=0; fixture integer; usuario integer; tipo integer; pendiente integer; aceptado integer; rechazado integer;
    details json; result json; version text; producto integer; campo text; stock_before numeric;
BEGIN
    SELECT min(id) INTO usuario FROM auth_usuarios WHERE estado=true;
    SELECT lo.id INTO pendiente FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='PENDIENTE' LIMIT 1;
    SELECT lo.id INTO aceptado FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='ACEPTADO' LIMIT 1;
    SELECT lo.id INTO rechazado FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='RECHAZADO' LIMIT 1;
    FOREACH codigo IN ARRAY ARRAY['01','03'] LOOP
        n:=n+1; fixture:=-930000-n;
        SELECT min(c.id_tipo_comprobante) INTO tipo FROM ven_comprobante c JOIN gen_lista_opciones tc ON tc.id=c.id_tipo_comprobante WHERE tc.descripcion=codigo;
        INSERT INTO ven_comprobante SELECT (jsonb_populate_record(NULL::ven_comprobante,to_jsonb(c)||jsonb_build_object(
            'id',fixture,'serie',CASE WHEN codigo='01' THEN 'F998' ELSE 'B998' END,'numero','00009999','id_tipo_comprobante',tipo,
            'id_estado_sunat',pendiente,'id_comprobante_origen',null,'id_condicion_pago',null,'id_medio_pago',null,
            'ticket_sunat',null,'hash_documento',null,'xml_firmado',null,'cdr_respuesta',null,'fecha_emision_cpe',null,
            'validez_sunat',null,'cpe_verificacion',null))).* FROM ven_comprobante c WHERE id=140;
        INSERT INTO ven_comprobante_detalle SELECT (jsonb_populate_record(NULL::ven_comprobante_detalle,to_jsonb(d)||jsonb_build_object(
            'id',fixture,'id_comprobante',fixture))).* FROM ven_comprobante_detalle d WHERE id_comprobante=140 AND estado=1 LIMIT 1;
        PERFORM pg_temp.ok((SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / comprobante nuevo permite edición');
        SELECT id_producto INTO producto FROM ven_comprobante_detalle WHERE id=fixture;
        UPDATE pro_stock SET stock=100 WHERE id_producto=producto AND id_almacen=2 AND estado=1;
        SELECT json_agg(to_jsonb(d)||jsonb_build_object('cantidad',cantidad+1) ORDER BY item) INTO details FROM ven_comprobante_detalle d WHERE id_comprobante=fixture AND estado=1;
        result:=ven_actualizar_comprobante(p_id=>fixture,p_detalles=>details,p_id_usuario_auditoria=>usuario,
            p_motivo_correccion=>'Corrección de cantidad antes de emitir',p_version_esperada=>(SELECT xmin::text FROM ven_comprobante WHERE id=fixture));
        PERFORM pg_temp.ok(result->>'error' IS NULL AND (SELECT stock=99 FROM pro_stock WHERE id_producto=producto AND id_almacen=2 AND estado=1),codigo||' / corrige cantidad y descuenta solo diferencia');
        PERFORM pg_temp.ok(EXISTS(SELECT 1 FROM ven_vsd_operacion o WHERE o.id_comprobante=fixture AND o.tipo='CORRECCION'),codigo||' / conserva snapshots de auditoría');
        SELECT xmin::text INTO version FROM ven_comprobante WHERE id=fixture;
        PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,usuario,'Edición con versión obsoleta','0'),'cambió',codigo||' / exige versión vigente');
        PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_id_usuario_auditoria=>%s,p_version_esperada=>%L)',fixture,usuario,version),'motivo',codigo||' / exige motivo');
        FOREACH campo IN ARRAY ARRAY['ticket_sunat','hash_documento','xml_firmado','cdr_respuesta'] LOOP
            EXECUTE format('UPDATE ven_comprobante SET %I=%L WHERE id=%s',campo,'Evidencia de envío local',fixture);
            PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_observaciones=>%L,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,'No debe guardarse',usuario,'Bloqueo de envío no confirmado',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
                'emisión',codigo||' / bloquea pendiente con '||campo);
            EXECUTE format('UPDATE ven_comprobante SET %I=NULL WHERE id=%s',campo,fixture);
        END LOOP;
        UPDATE ven_comprobante SET fecha_emision_cpe=CURRENT_DATE WHERE id=fixture;
        PERFORM pg_temp.ok((SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / fecha programada sin evidencia de envío conserva edición');
        UPDATE ven_comprobante SET fecha_emision_cpe=NULL,id_estado_sunat=aceptado WHERE id=fixture;
        PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,usuario,'Intento sobre comprobante aceptado',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
            'emisión',codigo||' / bloquea aceptado por SUNAT');
        UPDATE ven_comprobante c SET id_estado_sunat=pendiente,validez_sunat=jsonb_build_object('codigo','1','consulta',jsonb_build_object(
            'numeroSerie',c.serie,'numero',c.numero::numeric,'monto',c.total_importe,'fechaEmision',to_char(c.fecha,'DD/MM/YYYY'),'codComp',codigo)) WHERE id=fixture;
        PERFORM pg_temp.ok(NOT (SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / aceptación verificada prevalece sobre etiqueta pendiente');
        UPDATE ven_comprobante SET validez_sunat=NULL,id_estado_sunat=rechazado,cdr_respuesta='{"cdrResponse":{"code":"2325","description":"Rechazo definitivo de prueba"}}' WHERE id=fixture;
        PERFORM pg_temp.ok((SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / rechazo definitivo permite corregir antes de reemitir');
        FOREACH campo IN ARRAY ARRAY['','Texto ilegible','{"cdrResponse":{"code":"98"}}','{"cdrResponse":{"code":"0"}}'] LOOP
            UPDATE ven_comprobante SET cdr_respuesta=campo WHERE id=fixture;
            PERFORM pg_temp.ok(NOT (SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / etiqueta rechazado no basta sin prueba definitiva: '||campo);
        END LOOP;
        UPDATE ven_comprobante SET cdr_respuesta='{"tipo":"emision_por_confirmar"}' WHERE id=fixture;
        PERFORM pg_temp.ok(NOT (SELECT ven_comprobante_permite_edicion(c) FROM ven_comprobante c WHERE id=fixture),codigo||' / rechazo con resultado incierto permanece bloqueado');
        UPDATE ven_comprobante SET id_estado_sunat=pendiente,cdr_respuesta=NULL WHERE id=fixture;
        IF codigo='03' THEN
            INSERT INTO ven_resumen_diario(id,fecha,correlativo,id_estado_sunat) VALUES(-930020,CURRENT_DATE,'9999999999',pendiente);
            INSERT INTO ven_resumen_diario_detalle(id,id_resumen,id_comprobante,item) VALUES(-930021,-930020,fixture,1);
            PERFORM pg_temp.reject(format('SELECT ven_actualizar_comprobante(p_id=>%s,p_id_usuario_auditoria=>%s,p_motivo_correccion=>%L,p_version_esperada=>%L)',fixture,usuario,'Boleta incluida en resumen',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture)),
                'emisión','03 / bloquea boleta en resumen diario pendiente');
        END IF;
    END LOOP;
END $$;

DO $$
DECLARE codigo text; n integer:=0; fixture integer; old_id integer; new_id integer; usuario integer; tipo integer; pendiente integer; aceptado integer; payload jsonb; result json; stock_hash text;
BEGIN
    SELECT min(id) INTO usuario FROM auth_usuarios WHERE estado=true;
    SELECT lo.id INTO pendiente FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='PENDIENTE' LIMIT 1;
    SELECT lo.id INTO aceptado FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='ACEPTADO' LIMIT 1;
    FOREACH codigo IN ARRAY ARRAY['01','03'] LOOP
        n:=n+1; fixture:=-931000-n; old_id:=-932000-n; new_id:=-933000-n;
        SELECT min(c.id_tipo_comprobante) INTO tipo FROM ven_comprobante c JOIN gen_lista_opciones tc ON tc.id=c.id_tipo_comprobante WHERE tc.descripcion=codigo;
        INSERT INTO ven_comprobante SELECT (jsonb_populate_record(NULL::ven_comprobante,to_jsonb(c)||jsonb_build_object(
            'id',fixture,'serie',CASE WHEN codigo='01' THEN 'F997' ELSE 'B997' END,'numero','00009998','id_tipo_comprobante',tipo,
            'id_estado_sunat',pendiente,'id_comprobante_origen',null,'id_condicion_pago',null,'id_medio_pago',null,
            'ticket_sunat',null,'hash_documento',null,'xml_firmado',null,'cdr_respuesta',null,'fecha_emision_cpe',null,
            'validez_sunat',null,'cpe_verificacion',null))).* FROM ven_comprobante c WHERE id=134;
        INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object('id',old_id,
            'codigo_balon','LOCAL-CPE-RESERVA-'||codigo,'id_almacen',2,'id_cliente_ubicacion',null,'fecha_proxima_prueba_hidrostatica',CURRENT_DATE+365,
            'id_estado_balon',(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoBalon' AND lo.nombre='PENDIENTE_ENVIO' LIMIT 1)))).* FROM bal_balon b WHERE id=307;
        INSERT INTO bal_balon SELECT (jsonb_populate_record(NULL::bal_balon,to_jsonb(b)||jsonb_build_object('id',new_id,
            'codigo_balon','LOCAL-CPE-NUEVO-'||codigo,'id_estado_balon',(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoBalon' AND lo.nombre='DISPONIBLE' LIMIT 1)))).* FROM bal_balon b WHERE id=old_id;
        INSERT INTO ven_comprobante_detalle SELECT (jsonb_populate_record(NULL::ven_comprobante_detalle,to_jsonb(d)||jsonb_build_object('id',fixture,'id_comprobante',fixture,'id_balon',old_id))).*
            FROM ven_comprobante_detalle d WHERE id_comprobante=134 AND estado=1 LIMIT 1;
        payload:=jsonb_build_object('tipoOperacion','CORRECCION_RESERVA','solicitud',gen_random_uuid(),
            'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture),'idBalonActual',old_id,'idBalonNuevo',new_id,
            'idAlmacen',2,'cantidadGasDevuelta',0,'cantidadGasSalida',0,'condicionDevolucion','DISPONIBLE','motivo','Corregir balón de comprobante antes de emitir');
        SELECT md5(string_agg(row_to_json(s)::text,'' ORDER BY s.id)) INTO stock_hash FROM pro_stock s;
        result:=ven_cambiar_balon_vsd(fixture,payload,usuario);
        PERFORM pg_temp.ok(result->'registro'->>'id' IS NOT NULL AND EXISTS(SELECT 1 FROM ven_comprobante_detalle WHERE id=fixture AND id_balon=new_id),codigo||' / corrige balón reservado y conserva id de detalle');
        PERFORM pg_temp.ok(stock_hash=(SELECT md5(string_agg(row_to_json(s)::text,'' ORDER BY s.id)) FROM pro_stock s),codigo||' / reserva no duplica ni repone gas');
        result:=ven_confirmar_entrega_mostrador(fixture,usuario);
        UPDATE pro_stock SET stock=100 WHERE id_producto=10 AND id_almacen=2 AND estado=1;
        payload:=payload||jsonb_build_object('tipoOperacion','CAMBIO','solicitud',gen_random_uuid(),
            'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture),'idBalonActual',new_id,'idBalonNuevo',old_id,'cantidadGasSalida',10);
        result:=ven_cambiar_balon_vsd(fixture,payload,usuario);
        PERFORM pg_temp.ok(result->'registro'->>'id' IS NOT NULL AND EXISTS(SELECT 1 FROM ven_comprobante_detalle WHERE id=fixture AND id_balon=old_id),codigo||' / cambio físico previo a emitir actualiza el balón que imprimirá el comprobante');
        PERFORM pg_temp.ok((SELECT stock=90 FROM pro_stock WHERE id_producto=10 AND id_almacen=2 AND estado=1),codigo||' / cambio físico mueve únicamente gas del reemplazo');
        UPDATE ven_comprobante SET id_estado_sunat=aceptado WHERE id=fixture;
        payload:=payload||jsonb_build_object('solicitud',gen_random_uuid(),'versionEsperada',(SELECT xmin::text FROM ven_comprobante WHERE id=fixture));
        PERFORM pg_temp.reject(format('SELECT ven_cambiar_balon_vsd(%s,%L::jsonb,%s)',fixture,payload::text,usuario),'emisión',codigo||' / no permite cambio físico una vez aceptado');
        stock_hash:=pg_temp.state();
        result:=ven_revertir_efectos_comprobante(fixture,usuario);
        PERFORM pg_temp.ok(result->>'ok'='false' AND result->>'error' ILIKE '%cambios físicos%',codigo||' / bloquea reversión antigua que ignora el cambio físico');
        PERFORM pg_temp.ok(stock_hash=pg_temp.state(),codigo||' / bloqueo de anulación conserva stock y custodia');
    END LOOP;
END $$;

SELECT 'PASS '||label FROM vsd_results;
SELECT 'TOTAL '||count(*) FROM vsd_results;
ROLLBACK;

