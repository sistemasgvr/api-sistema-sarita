-- Run ONLY against the restored Docker snapshot using vsd-local.js.
-- Requiere aplicado database_sql/migraciones/sync-prod-desde-dev.sql (incluye la conversión VSD de caja;
-- antes en la migración suelta 20261026_caja_conversion_vsd.sql, ya retirada).
-- Todo el fixture y las operaciones se revierten (ROLLBACK al final).
--
-- Regla: el dinero de una VSD/NV cuenta siempre en la VSD (su fecha); el CPE de
-- conversión (boleta/factura con id_comprobante_origen = VSD) nunca suma a caja.
-- Cada caso se mide como diferencia antes/después para no depender de los datos
-- existentes del día.
BEGIN;
CREATE TEMP TABLE caja_results(label text);
CREATE TEMP TABLE caja_ctx(usuario integer, sucursal integer, almacen integer, cliente integer, producto integer);

CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO caja_results VALUES(label);
END $$;

-- Ventas del medio (fila de porMedio) en la caja de esa fecha y la sucursal del fixture.
CREATE FUNCTION pg_temp.medio(p_fecha date, p_medio text) RETURNS numeric LANGUAGE sql AS $$
  SELECT COALESCE(SUM((e->>'ventas')::numeric), 0)
  FROM json_array_elements(
         fin_caja_calcular_totales(p_fecha, (SELECT sucursal FROM caja_ctx))->'porMedio') e
  WHERE UPPER(e->>'medioPago') = UPPER(p_medio)
$$;

-- Venta de 1 × 150 del producto del fixture. Devuelve el id del comprobante;
-- un error devuelto en el JSON se convierte en excepción.
CREATE FUNCTION pg_temp.venta(p_tipo integer, p_serie text, p_fecha date, p_origen integer, p_pagos json)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE x record; r json;
BEGIN
  SELECT * INTO x FROM caja_ctx;
  r := ven_crear_comprobante(
         p_id_tipo_comprobante => p_tipo,
         p_serie => p_serie::varchar,
         p_fecha => p_fecha,
         p_id_cliente => x.cliente,
         p_detalles => json_build_array(json_build_object('id_producto', x.producto, 'cantidad', 1, 'precio_unitario', 150)),
         p_id_comprobante_origen => p_origen,
         p_id_sucursal => x.sucursal,
         p_id_almacen => x.almacen,
         p_id_usuario_auditoria => x.usuario,
         p_pagos => p_pagos);
  IF r->>'error' IS NOT NULL THEN
    RAISE EXCEPTION 'ven_crear_comprobante (%): %', p_serie, r->>'error';
  END IF;
  RETURN (r->'registro'->>'id')::integer;
END $$;

DO $$
DECLARE
  v_usuario integer; v_sucursal integer; v_almacen integer; v_cliente integer; v_producto integer;
  v_tipo_vsd integer; v_tipo_boleta integer; v_tipo_nc integer;
  v_efectivo integer; v_yape integer; v_cuenta_yape integer;
  v_abierta integer; v_aceptado integer; v_baja integer;
  -- Fechas futuras: lejos de los datos reales. Solo se abre la caja de D2 (una
  -- sucursal admite una sola caja abierta); lo de D1 se crea en D2 y se mueve
  -- con UPDATE fecha, igual que una VSD de un día anterior ya cerrado.
  v_d1 date := CURRENT_DATE + 40;
  v_d2 date := CURRENT_DATE + 41;
  v_result json; v_err text; v_libro json;
  v_vsd_a integer; v_vsd_c integer; v_conv_c integer; v_vsd_d integer; v_conv_d integer; v_nc integer;
  v_ef_d1 numeric; v_ya_d1 numeric; v_ef_d2 numeric; v_ef_d1_antes_d numeric;
BEGIN
  SELECT min(id) INTO v_usuario FROM auth_usuarios WHERE estado = true;
  SELECT a.id, a.id_sucursal INTO v_almacen, v_sucursal
    FROM gen_almacen a WHERE a.estado = 1 ORDER BY a.id LIMIT 1;
  SELECT min(id) INTO v_cliente FROM cli_clientes
    WHERE estado = 1 AND UPPER(COALESCE(codigo_interno, '')) <> 'CVARIOS';
  -- Producto que no mueve kardex: la prueba no depende del stock del almacén.
  SELECT min(p.id) INTO v_producto FROM pro_producto p
    WHERE p.estado = 1 AND NOT COALESCE(p.es_gas, false)
      AND NOT ven_producto_mueve_kardex_venta(p.id, NULL);
  SELECT lo.id INTO v_tipo_vsd FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion IN ('VSD', 'NV') AND lo.estado = 1
    ORDER BY (lo.descripcion = 'VSD') DESC, lo.id LIMIT 1;
  SELECT lo.id INTO v_tipo_boleta FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion = '03' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_tipo_nc FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion = '07' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_efectivo FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MedioPago' AND UPPER(lo.nombre) = 'EFECTIVO' LIMIT 1;
  SELECT lo.id INTO v_yape FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MedioPago' AND UPPER(lo.nombre) = 'YAPE' AND lo.estado = 1 LIMIT 1;
  -- Si YAPE exige cuenta bancaria, una cuenta de empresa asociada a ese medio.
  SELECT cm.id_cuenta_bancaria INTO v_cuenta_yape
    FROM gen_cuenta_medio_pago cm JOIN gen_cuenta_bancaria cb ON cb.id = cm.id_cuenta_bancaria
    WHERE cm.id_medio_pago = v_yape AND cm.estado = 1 AND cb.estado = 1 AND cb.ambito = 'EMPRESA'
    ORDER BY cm.es_predeterminada DESC, cm.id LIMIT 1;
  SELECT lo.id INTO v_abierta FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA' LIMIT 1;
  SELECT lo.id INTO v_aceptado FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'ACEPTADO' LIMIT 1;
  SELECT lo.id INTO v_baja FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'BAJA' LIMIT 1;

  PERFORM pg_temp.ok(v_usuario IS NOT NULL AND v_sucursal IS NOT NULL AND v_almacen IS NOT NULL
                     AND v_cliente IS NOT NULL AND v_producto IS NOT NULL,
                     'Fixture: usuario, sucursal/almacén, cliente y producto sin kardex');
  PERFORM pg_temp.ok(v_tipo_vsd IS NOT NULL AND v_tipo_boleta IS NOT NULL AND v_tipo_nc IS NOT NULL,
                     'Fixture: tipos VSD, boleta y nota de crédito');
  PERFORM pg_temp.ok(v_efectivo IS NOT NULL AND v_yape IS NOT NULL AND v_abierta IS NOT NULL
                     AND v_aceptado IS NOT NULL AND v_baja IS NOT NULL,
                     'Fixture: medios EFECTIVO/YAPE, caja ABIERTA, SUNAT ACEPTADO/BAJA');
  INSERT INTO caja_ctx VALUES (v_usuario, v_sucursal, v_almacen, v_cliente, v_producto);

  -- Saca de juego (solo dentro de la transacción) las sesiones de D1/D2 y cualquier
  -- caja abierta de la sucursal, que bloquearían la apertura de D2.
  UPDATE fin_caja_sesion SET estado = 0
  WHERE estado = 1 AND COALESCE(id_sucursal, 0) = v_sucursal
    AND (fecha IN (v_d1, v_d2) OR id_estado = v_abierta);
  v_result := fin_abrir_caja_sesion(v_d2, 0, v_sucursal, 'prueba conversión VSD', v_usuario, NULL::integer);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'Fixture: abrir caja de D2');

  -- a) Pago mixto: VSD de D1 por 150 cobrada EFECTIVO 100 + YAPE 50.
  v_ef_d1 := pg_temp.medio(v_d1, 'EFECTIVO');
  v_ya_d1 := pg_temp.medio(v_d1, 'YAPE');
  v_vsd_a := pg_temp.venta(v_tipo_vsd, 'VSD96', v_d2, NULL, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 100),
      json_build_object('idMedioPago', v_yape, 'monto', 50, 'idCuentaBancaria', v_cuenta_yape)));
  UPDATE ven_comprobante SET fecha = v_d1 WHERE id = v_vsd_a;
  PERFORM pg_temp.ok(pg_temp.medio(v_d1, 'EFECTIVO') - v_ef_d1 = 100, 'a) pago mixto: EFECTIVO de D1 sube 100');
  PERFORM pg_temp.ok(pg_temp.medio(v_d1, 'YAPE') - v_ya_d1 = 50, 'a) pago mixto: YAPE de D1 sube 50');

  -- b) Pagos que no cuadran con el total: ven_crear_comprobante propaga el mensaje
  -- de ven_sincronizar_pagos_comprobante con RAISE EXCEPTION (no como json 'error').
  v_err := NULL;
  BEGIN
    PERFORM pg_temp.venta(v_tipo_vsd, 'VSD96', v_d2, NULL, json_build_array(
        json_build_object('idMedioPago', v_efectivo, 'monto', 100)));
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
  END;
  PERFORM pg_temp.ok(v_err ILIKE '%Deben coincidir%', 'b) pagos 100 sobre total 150: error "Deben coincidir"');

  -- c) Mismo día: VSD de D2 + boleta de conversión de D2 → la caja sube 150, no 300 ni 0.
  v_ef_d2 := pg_temp.medio(v_d2, 'EFECTIVO');
  v_vsd_c := pg_temp.venta(v_tipo_vsd, 'VSD96', v_d2, NULL, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 150)));
  v_conv_c := pg_temp.venta(v_tipo_boleta, 'B995', v_d2, v_vsd_c, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 150)));
  PERFORM pg_temp.ok((SELECT id_comprobante_origen FROM ven_comprobante WHERE id = v_conv_c) = v_vsd_c,
                     'c) la boleta queda ligada a la VSD');
  PERFORM pg_temp.ok(pg_temp.medio(v_d2, 'EFECTIVO') - v_ef_d2 = 150, 'c) mismo día: EFECTIVO de D2 sube exactamente 150');

  -- d) Otro día: VSD de D1, boleta de conversión de D2 → D1 conserva +150, D2 no sube.
  v_ef_d1_antes_d := pg_temp.medio(v_d1, 'EFECTIVO');
  v_ef_d2 := pg_temp.medio(v_d2, 'EFECTIVO');
  v_vsd_d := pg_temp.venta(v_tipo_vsd, 'VSD96', v_d2, NULL, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 150)));
  UPDATE ven_comprobante SET fecha = v_d1 WHERE id = v_vsd_d;
  PERFORM pg_temp.ok(pg_temp.medio(v_d1, 'EFECTIVO') - v_ef_d1_antes_d = 150, 'd) VSD de D1 suma 150 en D1');
  v_conv_d := pg_temp.venta(v_tipo_boleta, 'B995', v_d2, v_vsd_d, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 150)));
  PERFORM pg_temp.ok(pg_temp.medio(v_d1, 'EFECTIVO') - v_ef_d1_antes_d = 150, 'd) otro día: D1 sigue con +150 tras convertir');
  PERFORM pg_temp.ok(pg_temp.medio(v_d2, 'EFECTIVO') - v_ef_d2 = 0, 'd) otro día: la conversión no sube D2');

  -- e) NC de 150 en efectivo sobre la boleta de conversión de (d): su origen es un
  -- CPE (no una VSD), así que resta en D2. ven_crear_comprobante exige el origen
  -- ACEPTADO por SUNAT para una NC.
  UPDATE ven_comprobante SET id_estado_sunat = v_aceptado WHERE id = v_conv_d;
  v_ef_d2 := pg_temp.medio(v_d2, 'EFECTIVO');
  v_nc := pg_temp.venta(v_tipo_nc, 'BC95', v_d2, v_conv_d, json_build_array(
      json_build_object('idMedioPago', v_efectivo, 'monto', 150)));
  PERFORM pg_temp.ok(pg_temp.medio(v_d2, 'EFECTIVO') - v_ef_d2 = -150, 'e) NC sobre la boleta de conversión baja D2 en 150');

  -- f) Boleta de conversión de (d) dada de BAJA: la VSD de D1 sigue contando.
  UPDATE ven_comprobante SET id_estado_sunat = v_baja WHERE id = v_conv_d;
  PERFORM pg_temp.ok(pg_temp.medio(v_d1, 'EFECTIVO') - v_ef_d1_antes_d = 150, 'f) conversión en BAJA: D1 sigue con +150');
  -- Vuelve a ACEPTADO para que (g) vea la boleta en el libro (BAJA se excluye de ventas).
  UPDATE ven_comprobante SET id_estado_sunat = v_aceptado WHERE id = v_conv_d;

  -- g) Libro diario D1..D2: la VSD de (d) se lista; la boleta de (d) se lista como
  -- documento con esConversionVsd = true, pero no aporta líneas a ventasPagos.
  v_libro := fin_obtener_libro_diario(v_d1, v_d2, NULL, v_sucursal);
  PERFORM pg_temp.ok(v_libro->>'error' IS NULL, 'g) libro diario sin error');
  PERFORM pg_temp.ok(EXISTS (
      SELECT 1 FROM json_array_elements(v_libro->'registro'->'ventas') e
      WHERE (e->>'id')::integer = v_vsd_d AND (e->>'esConversionVsd')::boolean = false),
    'g) la VSD de (d) aparece en ventas con esConversionVsd = false');
  PERFORM pg_temp.ok(EXISTS (
      SELECT 1 FROM json_array_elements(v_libro->'registro'->'ventas') e
      WHERE (e->>'id')::integer = v_conv_d AND (e->>'esConversionVsd')::boolean = true),
    'g) la boleta de (d) aparece en ventas con esConversionVsd = true');
  PERFORM pg_temp.ok(EXISTS (
      SELECT 1 FROM json_array_elements(v_libro->'registro'->'ventasPagos') e
      WHERE (e->>'idComprobante')::integer = v_vsd_d),
    'g) la VSD de (d) aporta su línea de cobro a ventasPagos');
  PERFORM pg_temp.ok(NOT EXISTS (
      SELECT 1 FROM json_array_elements(v_libro->'registro'->'ventasPagos') e
      WHERE (e->>'idComprobante')::integer = v_conv_d),
    'g) ninguna línea de ventasPagos es de la boleta de (d)');
END $$;

SELECT 'PASS '||label FROM caja_results;
SELECT 'TOTAL '||count(*) FROM caja_results;
ROLLBACK;
