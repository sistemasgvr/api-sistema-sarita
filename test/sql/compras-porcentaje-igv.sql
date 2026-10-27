-- Run ONLY against a local/restored snapshot (nunca DEV/PROD) que ya tenga aplicada
-- database_sql/migraciones/compras-porcentaje-igv.sql.
-- Verifica el % de IGV editable por compra: crear con 18 / 10.5 / 0, recálculo al agregar
-- detalle, cambio de % en la cabecera y rechazo de valores fuera de 0..100.
-- Todo el fixture y las operaciones se revierten (ROLLBACK al final).
BEGIN;
CREATE TEMP TABLE igv_results(label text);
CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO igv_results VALUES(label);
END $$;

DO $$
DECLARE
  v_usuario integer;
  v_proveedor integer;
  v_almacen integer;
  v_producto integer;
  v_medio integer;
  v_detalles jsonb;
  v_result json;
  v_id integer;
  v_c record;
BEGIN
  SELECT min(id) INTO v_usuario FROM auth_usuarios WHERE estado = true;
  SELECT min(id) INTO v_proveedor FROM cli_clientes WHERE estado = 1;
  SELECT min(id) INTO v_almacen FROM gen_almacen WHERE estado = 1;
  SELECT min(id) INTO v_producto FROM pro_producto WHERE estado = 1;
  -- Medio de pago al contado que no toca caja ni exige cuenta: así la prueba no depende
  -- de que haya una caja abierta.
  SELECT min(c.id_medio_pago) INTO v_medio FROM fin_medio_pago_config c
  WHERE c.estado = 1 AND NOT c.afecta_caja AND NOT c.requiere_cuenta_bancaria AND NOT c.es_credito;
  PERFORM pg_temp.ok(v_usuario IS NOT NULL AND v_proveedor IS NOT NULL AND v_almacen IS NOT NULL
                     AND v_producto IS NOT NULL AND v_medio IS NOT NULL,
                     'Fixture: usuario, proveedor, almacén, producto y medio de pago sin caja');

  -- Una línea de 118 que no mueve stock.
  v_detalles := jsonb_build_array(jsonb_build_object(
    'id_producto', v_producto, 'cantidad', 1, 'precio_unitario', 118, 'afecta_stock', false));

  -- 1) Sin p_porcentaje_igv (default 18): igv = total - total/1.18
  v_result := com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => 'TIGV', p_numero => '1', p_fecha => CURRENT_DATE,
    p_id_proveedor => v_proveedor, p_id_almacen => v_almacen, p_detalles => v_detalles,
    p_id_usuario_auditoria => v_usuario, p_id_medio_pago => v_medio, p_numero_operacion => 'OP-TIGV');
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, '18%: crear sin error');
  v_id := (v_result->'registro'->>'id')::integer;
  SELECT porcentaje_igv, sub_total, igv, total_importe INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.porcentaje_igv = 18, '18%: guarda porcentaje 18 por defecto');
  PERFORM pg_temp.ok(v_c.total_importe = 118, '18%: total 118');
  PERFORM pg_temp.ok(v_c.sub_total = ROUND(118 / 1.18, 4), '18%: sub_total = total/1.18');
  PERFORM pg_temp.ok(v_c.igv = 118 - ROUND(118 / 1.18, 4), '18%: igv = total - total/1.18');
  PERFORM pg_temp.ok((com_obtener_compra(v_id)->'registro'->>'porcentaje_igv')::numeric = 18, '18%: obtener devuelve porcentaje_igv');

  -- 2) 10.5 %
  v_result := com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => 'TIGV', p_numero => '2', p_fecha => CURRENT_DATE,
    p_id_proveedor => v_proveedor, p_id_almacen => v_almacen, p_detalles => v_detalles,
    p_id_usuario_auditoria => v_usuario, p_id_medio_pago => v_medio, p_numero_operacion => 'OP-TIGV',
    p_porcentaje_igv => 10.5);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, '10.5%: crear sin error');
  v_id := (v_result->'registro'->>'id')::integer;
  SELECT porcentaje_igv, sub_total, igv, total_importe INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.porcentaje_igv = 10.5, '10.5%: guarda porcentaje');
  PERFORM pg_temp.ok(v_c.sub_total = ROUND(118 / 1.105, 4), '10.5%: sub_total = total/1.105');
  PERFORM pg_temp.ok(v_c.igv = 118 - ROUND(118 / 1.105, 4), '10.5%: igv = total - total/1.105');

  -- 2b) Agregar detalle recalcula con el % de la compra (com_recalcular_totales_compra)
  v_result := com_crear_compra_detalle(
    p_id_comprobante => v_id, p_id_producto => v_producto, p_cantidad => 1, p_precio_unitario => 100,
    p_id_almacen => v_almacen, p_id_usuario_auditoria => v_usuario);
  SELECT porcentaje_igv, sub_total, igv, total_importe INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.total_importe = 218, '10.5%: detalle agregado suma al total');
  PERFORM pg_temp.ok(v_c.sub_total = ROUND(218 / 1.105, 4), '10.5%: recálculo de detalle usa 10.5');

  -- 3) 0 %: igv 0 y sub_total = total
  v_result := com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => 'TIGV', p_numero => '3', p_fecha => CURRENT_DATE,
    p_id_proveedor => v_proveedor, p_id_almacen => v_almacen, p_detalles => v_detalles,
    p_id_usuario_auditoria => v_usuario, p_id_medio_pago => v_medio, p_numero_operacion => 'OP-TIGV',
    p_porcentaje_igv => 0);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, '0%: crear sin error');
  v_id := (v_result->'registro'->>'id')::integer;
  SELECT porcentaje_igv, sub_total, igv, total_importe INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.porcentaje_igv = 0, '0%: guarda porcentaje 0');
  PERFORM pg_temp.ok(v_c.igv = 0, '0%: igv 0');
  PERFORM pg_temp.ok(v_c.sub_total = v_c.total_importe, '0%: sub_total = total');

  -- 4) Cambiar el % en la cabecera recalcula base e IGV sin tocar el total
  v_result := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => v_usuario,
                                             p_porcentaje_igv => 18);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'cabecera: cambio a 18 sin error');
  SELECT porcentaje_igv, sub_total, igv, total_importe INTO v_c FROM com_comprobante_compra WHERE id = v_id;
  PERFORM pg_temp.ok(v_c.porcentaje_igv = 18, 'cabecera: guarda 18');
  PERFORM pg_temp.ok(v_c.total_importe = 118, 'cabecera: total no cambia');
  PERFORM pg_temp.ok(v_c.igv = 118 - ROUND(118 / 1.18, 4), 'cabecera: recalcula igv');

  -- 4b) Sin p_porcentaje_igv se conserva el actual
  v_result := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_glosa => 'glosa igv',
                                             p_id_usuario_auditoria => v_usuario);
  PERFORM pg_temp.ok((SELECT porcentaje_igv FROM com_comprobante_compra WHERE id = v_id) = 18, 'cabecera: NULL conserva %');

  -- 5) Fuera de rango: error y sin cambios
  v_result := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => v_usuario,
                                             p_porcentaje_igv => 100.5);
  PERFORM pg_temp.ok(v_result->>'error' IS NOT NULL, 'cabecera: rechaza > 100');
  v_result := com_actualizar_compra_cabecera(p_id_comprobante => v_id, p_id_usuario_auditoria => v_usuario,
                                             p_porcentaje_igv => -1);
  PERFORM pg_temp.ok(v_result->>'error' IS NOT NULL, 'cabecera: rechaza < 0');
  PERFORM pg_temp.ok((SELECT porcentaje_igv FROM com_comprobante_compra WHERE id = v_id) = 18, 'cabecera: rango inválido no cambia %');

  v_result := com_crear_compra(
    p_id_tipo_comprobante => NULL, p_serie => 'TIGV', p_numero => '4', p_fecha => CURRENT_DATE,
    p_id_proveedor => v_proveedor, p_id_almacen => v_almacen, p_detalles => v_detalles,
    p_id_usuario_auditoria => v_usuario, p_id_medio_pago => v_medio, p_numero_operacion => 'OP-TIGV',
    p_porcentaje_igv => 101);
  PERFORM pg_temp.ok(v_result->>'error' IS NOT NULL, 'crear: rechaza > 100');
  PERFORM pg_temp.ok(NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE serie = 'TIGV' AND numero = '4'), 'crear: > 100 no inserta');

  -- El CHECK de la tabla también protege escrituras directas
  BEGIN
    UPDATE com_comprobante_compra SET porcentaje_igv = 150 WHERE id = v_id;
    PERFORM pg_temp.ok(false, 'tabla: CHECK rechaza 150');
  EXCEPTION WHEN check_violation THEN
    PERFORM pg_temp.ok(true, 'tabla: CHECK rechaza 150');
  END;

  -- Listado devuelve porcentaje_igv
  PERFORM pg_temp.ok(EXISTS (
    SELECT 1 FROM json_array_elements(com_listar_compras(p_busqueda => 'TIGV', p_limite => 50)->'registros') r
    WHERE (r->>'porcentaje_igv') IS NOT NULL), 'listar devuelve porcentaje_igv');
END $$;

SELECT 'PASS '||label FROM igv_results;
SELECT 'TOTAL '||count(*) FROM igv_results;
ROLLBACK;
