-- Run ONLY against a local/restored snapshot (nunca DEV/PROD) que ya tenga aplicada
-- database_sql/migraciones/20261112_compras_fecha_emision.sql.
-- Verifica fecha de gasto (mueve la caja) vs fecha de emisión (se completa después), el traslado
-- de una compra entre cajas y el recálculo del arqueo de una caja cerrada.
-- Usa sesiones de caja en 2099 para no chocar con datos reales. Todo se revierte (ROLLBACK).
BEGIN;
CREATE TEMP TABLE fge_results(label text);
CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO fge_results VALUES(label);
END $$;

-- Fixture compartido
CREATE TEMP TABLE fge_fx AS
SELECT
  (SELECT min(id) FROM auth_usuarios WHERE estado = true) AS usuario,
  (SELECT min(id) FROM cli_clientes WHERE estado = 1) AS proveedor,
  (SELECT min(id) FROM gen_almacen WHERE estado = 1) AS almacen,
  (SELECT min(id) FROM pro_producto WHERE estado = 1) AS producto,
  (SELECT min(id) FROM gen_sucursal WHERE estado = 1) AS sucursal,
  (SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA' LIMIT 1) AS est_abierta,
  (SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA' LIMIT 1) AS est_cerrada,
  -- Medio que afecta caja y no exige cuenta (efectivo)
  (SELECT min(c.id_medio_pago) FROM fin_medio_pago_config c
    WHERE c.estado = 1 AND c.afecta_caja AND c.es_efectivo AND NOT c.requiere_cuenta_bancaria AND NOT c.es_credito) AS medio_caja,
  -- Medio que no toca caja
  (SELECT min(c.id_medio_pago) FROM fin_medio_pago_config c
    WHERE c.estado = 1 AND NOT c.afecta_caja AND NOT c.requiere_cuenta_bancaria AND NOT c.es_credito) AS medio_sin_caja;

-- Crea una sesión de caja de prueba y devuelve su id
CREATE FUNCTION pg_temp.sesion(p_fecha date, p_cerrada boolean) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_id integer; f record;
BEGIN
  SELECT * INTO f FROM fge_fx;
  INSERT INTO fin_caja_sesion (fecha, id_sucursal, id_estado, monto_inicial, monto_efectivo_contado,
                               fecha_cierre, id_usuario_apertura)
  VALUES (p_fecha, f.sucursal, CASE WHEN p_cerrada THEN f.est_cerrada ELSE f.est_abierta END, 100,
          CASE WHEN p_cerrada THEN 100 END, CASE WHEN p_cerrada THEN NOW() END, f.usuario)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

-- Crea una compra de 118 y devuelve el JSON de com_crear_compra
CREATE FUNCTION pg_temp.compra(p_fecha date, p_medio integer, p_serie text DEFAULT NULL, p_numero text DEFAULT NULL,
                               p_fecha_emision date DEFAULT NULL, p_proveedor integer DEFAULT -1)
RETURNS json LANGUAGE plpgsql AS $$
DECLARE f record;
BEGIN
  SELECT * INTO f FROM fge_fx;
  RETURN com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => p_serie, p_numero => p_numero, p_fecha => p_fecha,
    p_id_proveedor => CASE WHEN p_proveedor = -1 THEN f.proveedor ELSE p_proveedor END,
    p_id_almacen => f.almacen,
    p_detalles => jsonb_build_array(jsonb_build_object(
      'id_producto', f.producto, 'cantidad', 1, 'precio_unitario', 118, 'afecta_stock', false)),
    p_id_sucursal => f.sucursal, p_id_usuario_auditoria => f.usuario, p_id_medio_pago => p_medio,
    p_fecha_emision => p_fecha_emision);
END $$;

CREATE FUNCTION pg_temp.pagos(p_fecha date) RETURNS numeric LANGUAGE sql AS $$
  SELECT COALESCE((fin_caja_calcular_totales(p_fecha, (SELECT sucursal FROM fge_fx))->>'pagosProveedor')::numeric, 0)
$$;

-- 1) Esquema y recálculo de arqueo
DO $$
DECLARE f record; v_abierta integer; v_cerrada integer; v_s record; v_r json; v_cierre timestamp;
BEGIN
  SELECT * INTO f FROM fge_fx;
  PERFORM pg_temp.ok(f.usuario IS NOT NULL AND f.proveedor IS NOT NULL AND f.almacen IS NOT NULL
                     AND f.producto IS NOT NULL AND f.sucursal IS NOT NULL AND f.medio_caja IS NOT NULL
                     AND f.medio_sin_caja IS NOT NULL AND f.est_abierta IS NOT NULL AND f.est_cerrada IS NOT NULL,
                     'Fixture completo');

  PERFORM pg_temp.ok(EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'com_comprobante_compra' AND column_name = 'fecha_emision'), 'columna fecha_emision existe');

  v_abierta := pg_temp.sesion(DATE '2099-01-01', false);
  INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto) VALUES (v_abierta, 'AJUSTE_COMPRA', 1);
  PERFORM pg_temp.ok(true, 'CHECK admite AJUSTE_COMPRA');

  PERFORM pg_temp.ok(fin_caja_recalcular_arqueo(v_abierta, f.usuario) IS NULL, 'recalcular arqueo: caja abierta → NULL');
  PERFORM pg_temp.ok(fin_caja_recalcular_arqueo(-1, f.usuario) IS NULL, 'recalcular arqueo: sesión inexistente → NULL');

  -- Caja cerrada con fondo 100, contado 100 y sin movimientos; luego aparece un gasto de 30 en efectivo.
  v_cerrada := pg_temp.sesion(DATE '2099-01-02', true);
  UPDATE fin_caja_sesion SET monto_esperado = 100, diferencia = 0 WHERE id = v_cerrada;
  SELECT fecha_cierre INTO v_cierre FROM fin_caja_sesion WHERE id = v_cerrada;
  INSERT INTO fin_caja_gasto (id_sesion, fecha, concepto, monto, id_medio_pago)
  VALUES (v_cerrada, DATE '2099-01-02', 'prueba', 30, f.medio_caja);

  v_r := fin_caja_recalcular_arqueo(v_cerrada, f.usuario);
  SELECT s.*, UPPER(est.nombre) AS est INTO v_s
  FROM fin_caja_sesion s JOIN gen_lista_opciones est ON est.id = s.id_estado WHERE s.id = v_cerrada;
  PERFORM pg_temp.ok((v_r->>'montoEsperadoAnterior')::numeric = 100, 'recalcular: devuelve esperado anterior');
  PERFORM pg_temp.ok(v_s.monto_esperado = 70, 'recalcular: esperado = 100 - 30');
  PERFORM pg_temp.ok(v_s.diferencia = 30, 'recalcular: diferencia = contado - esperado');
  PERFORM pg_temp.ok(v_s.monto_efectivo_contado = 100, 'recalcular: no toca el contado');
  PERFORM pg_temp.ok(v_s.est = 'CERRADA', 'recalcular: sigue CERRADA');
  PERFORM pg_temp.ok(v_s.fecha_cierre = v_cierre, 'recalcular: no toca fecha_cierre');
  PERFORM pg_temp.ok((v_s.totales_cierre->>'efectivoNeto')::numeric
                     = (fin_caja_calcular_totales(DATE '2099-01-02', f.sucursal)->>'efectivoNeto')::numeric,
                     'recalcular: totales_cierre = totales en vivo');
END $$;

-- 2) Crear compra: fecha de emisión opcional, proveedor obligatorio, caja por fecha de gasto
DO $$
DECLARE f record; v_r json; v_id integer; v_c record; v_abierta integer; v_antes numeric;
BEGIN
  SELECT * INTO f FROM fge_fx;

  v_r := pg_temp.compra(CURRENT_DATE, f.medio_sin_caja);
  PERFORM pg_temp.ok(v_r->>'error' IS NULL, 'crear: sin serie/número/emisión OK');
  v_id := (v_r->'registro'->'cabecera'->>'id')::integer;
  SELECT * INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.fecha_emision IS NULL AND v_c.serie IS NULL AND v_c.numero IS NULL, 'crear: comprobante vacío queda NULL');

  v_r := pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, 'TFGE', '1', NULL, NULL);
  PERFORM pg_temp.ok(v_r->>'error' = 'El proveedor es obligatorio', 'crear: sin proveedor → error');
  PERFORM pg_temp.ok(NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE serie = 'TFGE' AND numero = '1'), 'crear: sin proveedor no inserta');

  v_r := pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, 'TFGE', '2', CURRENT_DATE + 1);
  PERFORM pg_temp.ok(v_r->>'error' = 'La fecha de emisión no puede ser posterior a hoy', 'crear: emisión futura → error');

  v_r := pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, 'TFGE', '3', CURRENT_DATE - 3);
  PERFORM pg_temp.ok(v_r->>'error' IS NULL, 'crear: emisión pasada OK');
  PERFORM pg_temp.ok((SELECT fecha_emision FROM com_comprobante_compra WHERE id = (v_r->'registro'->'cabecera'->>'id')::integer) = CURRENT_DATE - 3,
                     'crear: guarda fecha_emision');

  v_r := pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, '  ', '  ');
  PERFORM pg_temp.ok((SELECT serie IS NULL AND numero IS NULL FROM com_comprobante_compra
                      WHERE id = (v_r->'registro'->'cabecera'->>'id')::integer), 'crear: serie/número en blanco → NULL');

  -- Fecha de gasto en una caja abierta de otro día
  v_abierta := pg_temp.sesion(DATE '2099-01-10', false);
  v_antes := pg_temp.pagos(DATE '2099-01-10');
  v_r := pg_temp.compra(DATE '2099-01-10', f.medio_caja);
  PERFORM pg_temp.ok(v_r->>'error' IS NULL, 'crear: fecha de gasto con caja abierta OK');
  PERFORM pg_temp.ok(pg_temp.pagos(DATE '2099-01-10') = v_antes + 118, 'crear: la caja del día de gasto suma el pago');

  PERFORM pg_temp.sesion(DATE '2099-01-20', true);
  BEGIN
    v_r := pg_temp.compra(DATE '2099-01-20', f.medio_caja);
    PERFORM pg_temp.ok(COALESCE(v_r->>'error', '') LIKE '%ya está cerrada%', 'crear: caja cerrada → error');
  EXCEPTION WHEN raise_exception THEN
    PERFORM pg_temp.ok(SQLERRM LIKE '%ya está cerrada%', 'crear: caja cerrada → error');
  END;
END $$;

-- 3) Editar cabecera: completar comprobante y mover la fecha de gasto
CREATE FUNCTION pg_temp.mover(p_id integer, p_fecha date) RETURNS json LANGUAGE sql AS $$
  SELECT com_actualizar_compra_cabecera(p_id_comprobante => p_id, p_id_usuario_auditoria => (SELECT usuario FROM fge_fx),
                                        p_fecha => p_fecha)
$$;
CREATE FUNCTION pg_temp.eventos(p_sesion integer) RETURNS bigint LANGUAGE sql AS $$
  SELECT count(*) FROM fin_caja_sesion_evento WHERE id_sesion = p_sesion AND tipo = 'AJUSTE_COMPRA'
$$;

DO $$
DECLARE f record; v_r json; v_id integer; v_c record; v_t1 numeric; v_t2 numeric;
        s_a integer; s_b integer; s_cer integer; s_cer2 integer; s_cer3 integer; v_id2 integer; v_msg text;
        v_s record; v_ev record; v_esp_antes numeric;
BEGIN
  SELECT * INTO f FROM fge_fx;
  s_a := pg_temp.sesion(DATE '2099-02-10', false);
  s_b := pg_temp.sesion(DATE '2099-02-11', false);

  -- 3.1 Completar comprobante no mueve caja
  v_id := (pg_temp.compra(DATE '2099-02-10', f.medio_caja)->'registro'->'cabecera'->>'id')::integer;
  v_t1 := pg_temp.pagos(DATE '2099-02-10');
  v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => f.usuario,
           p_fecha_emision => CURRENT_DATE - 1, p_serie => 'TFGE', p_numero => '31', p_id_tipo_comprobante => NULL);
  SELECT * INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.serie = 'TFGE' AND v_c.numero = '31' AND v_c.fecha_emision = CURRENT_DATE - 1, 'editar: completa comprobante');
  PERFORM pg_temp.ok(pg_temp.pagos(DATE '2099-02-10') = v_t1, 'editar: completar comprobante no cambia la caja');
  PERFORM pg_temp.ok(pg_temp.eventos(s_a) = 0, 'editar: completar comprobante no deja evento');

  -- 3.2 Origen abierta → destino abierta
  v_t1 := pg_temp.pagos(DATE '2099-02-10'); v_t2 := pg_temp.pagos(DATE '2099-02-11');
  v_r := pg_temp.mover(v_id, DATE '2099-02-11');
  PERFORM pg_temp.ok(pg_temp.pagos(DATE '2099-02-10') = v_t1 - 118, 'mover: origen abierta resta el pago');
  PERFORM pg_temp.ok(pg_temp.pagos(DATE '2099-02-11') = v_t2 + 118, 'mover: destino suma el pago');
  SELECT * INTO v_ev FROM fin_caja_sesion_evento WHERE id_sesion = s_a AND tipo = 'AJUSTE_COMPRA';
  PERFORM pg_temp.ok(v_ev.monto = 118 AND v_ev.observacion LIKE '%11/02/2099%', 'mover: evento AJUSTE_COMPRA en origen');

  -- 3.5 Misma fecha → sin evento nuevo
  v_r := pg_temp.mover(v_id, DATE '2099-02-11');
  PERFORM pg_temp.ok(pg_temp.eventos(s_b) = 0, 'mover: misma fecha no deja evento');

  -- 3.3 Origen cerrada → destino abierta: recalcula arqueo
  s_cer := pg_temp.sesion(DATE '2099-02-12', false);
  v_id := (pg_temp.compra(DATE '2099-02-12', f.medio_caja)->'registro'->'cabecera'->>'id')::integer;
  PERFORM fin_cerrar_caja_sesion(s_cer, 100, NULL, f.usuario);
  SELECT monto_esperado INTO v_esp_antes FROM fin_caja_sesion WHERE id = s_cer;
  v_r := pg_temp.mover(v_id, DATE '2099-02-11');
  SELECT s.*, UPPER(est.nombre) AS est INTO v_s FROM fin_caja_sesion s
    JOIN gen_lista_opciones est ON est.id = s.id_estado WHERE s.id = s_cer;
  PERFORM pg_temp.ok(v_s.est = 'CERRADA', 'mover desde cerrada: origen sigue CERRADA');
  PERFORM pg_temp.ok(v_s.monto_esperado = v_esp_antes + 118, 'mover desde cerrada: esperado sube en el total');
  PERFORM pg_temp.ok(v_s.diferencia = 100 - v_s.monto_esperado, 'mover desde cerrada: diferencia recalculada');
  SELECT * INTO v_ev FROM fin_caja_sesion_evento WHERE id_sesion = s_cer AND tipo = 'AJUSTE_COMPRA';
  PERFORM pg_temp.ok(v_ev.diferencia = v_s.diferencia AND v_ev.observacion LIKE '%esperado%', 'mover desde cerrada: evento con nueva diferencia');

  -- 3.4 Destino cerrada o sin caja → error y nada cambia
  s_cer2 := pg_temp.sesion(DATE '2099-02-13', true);
  -- El error se captura en v_msg y se verifica fuera del bloque: así un FAIL de pg_temp.ok no queda
  -- atrapado por el propio EXCEPTION.
  v_msg := NULL;
  BEGIN
    v_r := pg_temp.mover(v_id, DATE '2099-02-13');
  EXCEPTION WHEN raise_exception THEN
    v_msg := SQLERRM;
  END;
  PERFORM pg_temp.ok(COALESCE(v_msg, '') LIKE '%ya está cerrada%', 'mover a caja cerrada → error');
  PERFORM pg_temp.ok((SELECT fecha FROM com_comprobante_compra WHERE id = v_id) = DATE '2099-02-11', 'mover a caja cerrada: fecha no cambia');
  v_msg := NULL;
  BEGIN
    v_r := pg_temp.mover(v_id, DATE '2099-02-14');
  EXCEPTION WHEN raise_exception THEN
    v_msg := SQLERRM;
  END;
  PERFORM pg_temp.ok(COALESCE(v_msg, '') LIKE '%No hay caja abierta%', 'mover a día sin caja → error');

  -- 3.4b Mover la fecha NO desactiva la validación de origen si además cambia el medio de pago
  s_cer3 := pg_temp.sesion(DATE '2099-02-16', false);
  v_id2 := (pg_temp.compra(DATE '2099-02-16', f.medio_caja)->'registro'->'cabecera'->>'id')::integer;
  PERFORM fin_cerrar_caja_sesion(s_cer3, 100, NULL, f.usuario);
  v_msg := NULL;
  BEGIN
    v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id2, p_id_usuario_auditoria => f.usuario,
             p_id_medio_pago => f.medio_sin_caja, p_fecha => DATE '2099-02-11');
  EXCEPTION WHEN raise_exception THEN
    v_msg := SQLERRM;
  END;
  PERFORM pg_temp.ok(COALESCE(v_msg, '') LIKE '%ya está cerrada%', 'mover + cambiar medio desde caja cerrada → error');
  PERFORM pg_temp.ok((SELECT fecha FROM com_comprobante_compra WHERE id = v_id2) = DATE '2099-02-16', 'mover + cambiar medio: nada cambia');

  -- 3.6 Medio que no afecta caja: mueve sin validar caja ni dejar evento
  v_id := (pg_temp.compra(DATE '2099-02-10', f.medio_sin_caja)->'registro'->'cabecera'->>'id')::integer;
  v_r := pg_temp.mover(v_id, DATE '2099-02-14');
  PERFORM pg_temp.ok((SELECT fecha FROM com_comprobante_compra WHERE id = v_id) = DATE '2099-02-14', 'mover sin caja: cambia fecha');
  PERFORM pg_temp.ok(pg_temp.eventos(s_a) = 1, 'mover sin caja: sin evento');

  -- 3.7 Afecta caja pero el día de origen no tiene sesión (dato antiguo)
  INSERT INTO com_comprobante_compra (fecha, id_proveedor, id_sucursal, id_almacen, total_importe, id_medio_pago, estado)
  VALUES (DATE '2099-02-15', f.proveedor, f.sucursal, f.almacen, 50, f.medio_caja, 1) RETURNING id INTO v_id;
  v_r := pg_temp.mover(v_id, DATE '2099-02-11');
  PERFORM pg_temp.ok((SELECT fecha FROM com_comprobante_compra WHERE id = v_id) = DATE '2099-02-11', 'mover desde día sin caja: OK');

  -- 3.8 Serie en blanco y emisión futura
  v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => f.usuario, p_serie => '  ');
  PERFORM pg_temp.ok((SELECT serie FROM com_comprobante_compra WHERE id = v_id) IS NULL, 'editar: serie en blanco → NULL');
  v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => f.usuario,
           p_fecha_emision => CURRENT_DATE + 1);
  PERFORM pg_temp.ok(v_r->>'error' = 'La fecha de emisión no puede ser posterior a hoy', 'editar: emisión futura → error');

  -- 3.10 Vaciar fecha de emisión y tipo de comprobante (vuelve a "pendiente")
  UPDATE com_comprobante_compra
  SET fecha_emision = CURRENT_DATE,
      id_tipo_comprobante = (SELECT min(id) FROM gen_lista_opciones)
  WHERE id = v_id;
  v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => f.usuario,
           p_quitar_fecha_emision => true, p_id_tipo_comprobante => 0);
  PERFORM pg_temp.ok((SELECT fecha_emision IS NULL AND id_tipo_comprobante IS NULL FROM com_comprobante_compra WHERE id = v_id),
                     'editar: vacía fecha de emisión y tipo');
  -- Sin indicarlo, se conservan
  UPDATE com_comprobante_compra SET fecha_emision = CURRENT_DATE WHERE id = v_id;
  v_r := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => f.usuario);
  PERFORM pg_temp.ok((SELECT fecha_emision FROM com_comprobante_compra WHERE id = v_id) = CURRENT_DATE,
                     'editar: sin quitar, conserva fecha de emisión');
END $$;

-- 3.9 Compra al crédito con pagos: mover fecha no toca la CxP
DO $$
DECLARE f record; v_id integer; v_credito integer; v_cta record; v_cta2 record;
BEGIN
  SELECT * INTO f FROM fge_fx;
  SELECT cp.id INTO v_credito FROM gen_condicion_pago cp
  WHERE cp.estado = 1 AND COALESCE(cp.dias_credito, 0) > 0 AND COALESCE(cp.numero_cuotas, 0) <= 1 LIMIT 1;
  IF v_credito IS NULL THEN
    PERFORM pg_temp.ok(true, 'crédito con pagos: SIN condición crédito en la base, se omite');
    RETURN;
  END IF;
  v_id := (com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => NULL, p_numero => NULL, p_fecha => DATE '2099-03-01',
    p_id_proveedor => f.proveedor, p_id_almacen => f.almacen,
    p_detalles => jsonb_build_array(jsonb_build_object('id_producto', f.producto, 'cantidad', 1, 'precio_unitario', 118, 'afecta_stock', false)),
    p_id_sucursal => f.sucursal, p_id_condicion_pago => v_credito, p_id_usuario_auditoria => f.usuario,
    p_fecha_vencimiento_cxp => DATE '2099-03-31')->'registro'->'cabecera'->>'id')::integer;
  SELECT * INTO v_cta FROM fin_cuenta WHERE id_comprobante_compra = v_id AND estado = 1;
  PERFORM pg_temp.ok(v_cta.id IS NOT NULL, 'crédito: genera CxP');
  -- Simula un pago registrado: com_sincronizar_cxp_compra no reconstruye una CxP con pagos
  INSERT INTO fin_pago (id_cuenta, monto, fecha_pago, estado)
  VALUES (v_cta.id, 10, DATE '2099-03-02', 1);
  PERFORM pg_temp.mover(v_id, DATE '2099-03-05');
  SELECT * INTO v_cta2 FROM fin_cuenta WHERE id = v_cta.id;
  PERFORM pg_temp.ok((SELECT fecha FROM com_comprobante_compra WHERE id = v_id) = DATE '2099-03-05', 'crédito con pagos: cambia fecha de gasto');
  PERFORM pg_temp.ok(v_cta2.estado = 1 AND v_cta2.fecha_vencimiento = v_cta.fecha_vencimiento, 'crédito con pagos: CxP intacta');
  PERFORM pg_temp.ok(EXISTS (SELECT 1 FROM fin_pago WHERE id_cuenta = v_cta.id AND fecha_pago = DATE '2099-03-02'),
                     'crédito con pagos: fecha del pago intacta');
END $$;

-- 4) Listar / obtener: fecha_emision y "pendiente de comprobante"
DO $$
DECLARE f record; v_sin_emision integer; v_completa integer; v_reg json;
BEGIN
  SELECT * INTO f FROM fge_fx;
  v_sin_emision := (pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, 'TFGL', '1')->'registro'->'cabecera'->>'id')::integer;
  v_completa := (pg_temp.compra(CURRENT_DATE, f.medio_sin_caja, 'TFGL', '2', CURRENT_DATE)->'registro'->'cabecera'->>'id')::integer;

  SELECT r INTO v_reg FROM json_array_elements(com_listar_compras(p_busqueda => 'TFGL', p_limite => 50)->'registros') r
  WHERE (r->>'id')::integer = v_sin_emision;
  PERFORM pg_temp.ok((v_reg->>'tiene_comprobante')::boolean = false, 'listar: serie+número sin emisión → pendiente');
  SELECT r INTO v_reg FROM json_array_elements(com_listar_compras(p_busqueda => 'TFGL', p_limite => 50)->'registros') r
  WHERE (r->>'id')::integer = v_completa;
  PERFORM pg_temp.ok((v_reg->>'tiene_comprobante')::boolean = true, 'listar: comprobante completo');
  PERFORM pg_temp.ok((v_reg->>'fecha_emision')::date = CURRENT_DATE, 'listar: devuelve fecha_emision');

  PERFORM pg_temp.ok(EXISTS (SELECT 1 FROM json_array_elements(
      com_listar_compras(p_busqueda => 'TFGL', p_limite => 50, p_sin_comprobante => true)->'registros') r
    WHERE (r->>'id')::integer = v_sin_emision), 'filtro sin comprobante incluye la que no tiene emisión');
  PERFORM pg_temp.ok(NOT EXISTS (SELECT 1 FROM json_array_elements(
      com_listar_compras(p_busqueda => 'TFGL', p_limite => 50, p_sin_comprobante => false)->'registros') r
    WHERE (r->>'id')::integer = v_sin_emision), 'filtro con comprobante excluye la que no tiene emisión');
  PERFORM pg_temp.ok((com_obtener_compra(v_completa)->'registro'->'cabecera'->>'fecha_emision')::date = CURRENT_DATE, 'obtener: devuelve fecha_emision');
END $$;

SELECT 'PASS '||label FROM fge_results;
SELECT 'TOTAL '||count(*) FROM fge_results;
ROLLBACK;
