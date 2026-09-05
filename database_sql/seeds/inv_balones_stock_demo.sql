-- Seed DEV: tipos de balón + cilindros + stock vía movimientos (kardex cuadra).
-- Idempotente por códigos DEMO-*.
--
-- Flujo:
--  1) Gas: afecta_stock = true (Fase 1)
--  2) Tipos de balón (si no existen)
--  3) Accesorios: AJUSTE MAS (PRODUCTO)
--  4) Cilindros: bal_crear_balon + ENTRADA_LLENADO (BALON) con m³/kg de gas

DO $$
DECLARE
  v_user INT;
  v_alm_principal INT := 2; -- Almacén principal Picsi
  v_alm_secundario INT := 3;
  v_um_mt3 INT;
  v_um_kg INT;
  v_um_unid INT;
  v_prop_empresa INT;
  v_estado_almacen INT;
  v_marca INT;
  v_tipo_oxi6 INT;
  v_tipo_oxi10 INT;
  v_tipo_ace INT;
  v_tipo_nit INT;
  v_gas_oxi_med INT;
  v_gas_oxi_ind INT;
  v_gas_ace INT;
  v_gas_nit INT;
  v_res JSON;
  v_id_balon INT;
  v_i INT;
  v_codigo VARCHAR(50);
  v_cap NUMERIC;
  r_acc RECORD;
BEGIN
  SELECT id INTO v_user FROM auth_usuarios WHERE estado = TRUE ORDER BY id LIMIT 1;

  SELECT lo.id INTO v_um_mt3 FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'UnidadMedida' AND lo.nombre = 'MT3' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_um_kg FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'UnidadMedida' AND lo.nombre = 'KG' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_um_unid FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'UnidadMedida' AND lo.nombre = 'UNID' AND lo.estado = 1 LIMIT 1;

  SELECT lo.id INTO v_prop_empresa FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'EMPRESA' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_estado_almacen FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_marca FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'MarcaCilindro' AND lo.nombre = 'BTIC-JP' AND lo.estado = 1 LIMIT 1;

  SELECT id INTO v_gas_oxi_med FROM pro_producto WHERE codigo = 'GAS-OXI-MED' AND estado = 1;
  SELECT id INTO v_gas_oxi_ind FROM pro_producto WHERE codigo = 'GAS-OXI-IND' AND estado = 1;
  SELECT id INTO v_gas_ace FROM pro_producto WHERE codigo = 'GAS-ACE-IND' AND estado = 1;
  SELECT id INTO v_gas_nit FROM pro_producto WHERE codigo = 'GAS-NIT-IND' AND estado = 1;

  IF v_gas_oxi_med IS NULL OR v_alm_principal IS NULL THEN
    RAISE EXCEPTION 'Faltan productos gas o almacén principal para el seed';
  END IF;

  -- Fase 1: el gas se stockea en pro_stock
  UPDATE pro_producto
  SET afecta_stock = TRUE, fecha_modificacion = NOW()
  WHERE es_gas = TRUE AND estado = 1 AND COALESCE(afecta_stock, FALSE) = FALSE;

  -- Tipos de balón
  IF NOT EXISTS (SELECT 1 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Medicinal 6 m³' AND estado = 1) THEN
    v_res := bal_crear_tipo_balon(
      p_nombre => 'Oxígeno Medicinal 6 m³',
      p_id_gas => v_gas_oxi_med,
      p_capacidad => 6,
      p_id_unidad_medida => v_um_mt3,
      p_vigencia_ph_anios => 5,
      p_presion_llenado_psi => 200,
      p_id_usuario_auditoria => v_user
    );
    IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Medicinal 10 m³' AND estado = 1) THEN
    v_res := bal_crear_tipo_balon(
      p_nombre => 'Oxígeno Medicinal 10 m³',
      p_id_gas => v_gas_oxi_med,
      p_capacidad => 10,
      p_id_unidad_medida => v_um_mt3,
      p_vigencia_ph_anios => 5,
      p_presion_llenado_psi => 200,
      p_id_usuario_auditoria => v_user
    );
    IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Industrial 6 m³' AND estado = 1) THEN
    v_res := bal_crear_tipo_balon(
      p_nombre => 'Oxígeno Industrial 6 m³',
      p_id_gas => v_gas_oxi_ind,
      p_capacidad => 6,
      p_id_unidad_medida => v_um_mt3,
      p_vigencia_ph_anios => 5,
      p_presion_llenado_psi => 200,
      p_id_usuario_auditoria => v_user
    );
    IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM bal_tipo_balon WHERE nombre = 'Acetileno 5 kg' AND estado = 1) THEN
    v_res := bal_crear_tipo_balon(
      p_nombre => 'Acetileno 5 kg',
      p_id_gas => v_gas_ace,
      p_capacidad => 5,
      p_id_unidad_medida => v_um_kg,
      p_vigencia_ph_anios => 5,
      p_id_usuario_auditoria => v_user
    );
    IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM bal_tipo_balon WHERE nombre = 'Nitrógeno 6 m³' AND estado = 1) THEN
    v_res := bal_crear_tipo_balon(
      p_nombre => 'Nitrógeno 6 m³',
      p_id_gas => v_gas_nit,
      p_capacidad => 6,
      p_id_unidad_medida => v_um_mt3,
      p_vigencia_ph_anios => 5,
      p_id_usuario_auditoria => v_user
    );
    IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
  END IF;

  SELECT id INTO v_tipo_oxi6 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Medicinal 6 m³' AND estado = 1;
  SELECT id INTO v_tipo_oxi10 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Medicinal 10 m³' AND estado = 1;
  SELECT id INTO v_tipo_ace FROM bal_tipo_balon WHERE nombre = 'Acetileno 5 kg' AND estado = 1;
  SELECT id INTO v_tipo_nit FROM bal_tipo_balon WHERE nombre = 'Nitrógeno 6 m³' AND estado = 1;

  -- Accesorios: stock con AJUSTE (solo si aún no hay kardex de carga demo)
  IF NOT EXISTS (
    SELECT 1 FROM inv_movimiento m
    WHERE m.estado = 1 AND m.glosa = 'Carga inicial DEV (accesorios)'
  ) THEN
    FOR r_acc IN
      SELECT p.id AS id_producto, v.qty
      FROM (VALUES
        ('VAL-01', 40::numeric),
        ('ACC-REG-OXI', 15),
        ('ACC-REG-ACE', 10),
        ('ACC-VAL-CIL', 25),
        ('ACC-MAN-63', 20),
        ('ACC-MAN-100', 12),
        ('ACC-MAN-OXI3', 30),
        ('ACC-ADP-OXI', 18),
        ('ACC-LLA-VAL', 22),
        ('ACC-CANULA-OXI', 50),
        ('ACC-VASO-HUM', 35)
      ) AS v(codigo, qty)
      JOIN pro_producto p ON p.codigo = v.codigo AND p.estado = 1
    LOOP
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'PRODUCTO',
        p_codigo_tipo_movimiento => 'AJUSTE',
        p_id_producto => r_acc.id_producto,
        p_cantidad => r_acc.qty,
        p_id_almacen_origen => v_alm_principal,
        p_glosa => 'Carga inicial DEV (accesorios)',
        p_sentido_ajuste => 'MAS',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN
        RAISE EXCEPTION 'Accesorio %: %', r_acc.id_producto, v_res->>'error';
      END IF;
    END LOOP;
  END IF;

  -- Helper inline: crear balón + llenado si no existe
  -- Oxígeno medicinal 6m³ × 8 en principal
  FOR v_i IN 1..8 LOOP
    v_codigo := format('DEMO-OXM6-%s', lpad(v_i::text, 3, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_principal,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_oxi6,
        p_id_producto_gas => v_gas_oxi_med,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2023::smallint,
        p_mes_fabricacion => ((v_i % 12) + 1)::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '1 year')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro demo DEV'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
      v_id_balon := (v_res->'registro'->>'id')::INT;
      v_cap := 6;
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'BALON',
        p_codigo_tipo_movimiento => 'ENTRADA_LLENADO',
        p_id_balon => v_id_balon,
        p_id_producto => v_gas_oxi_med,
        p_cantidad => v_cap,
        p_id_almacen_origen => v_alm_principal,
        p_id_almacen_destino => v_alm_principal,
        p_glosa => 'Carga inicial DEV (llenado)',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;

  -- Oxígeno medicinal 10m³ × 4
  FOR v_i IN 1..4 LOOP
    v_codigo := format('DEMO-OXM10-%s', lpad(v_i::text, 3, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_principal,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_oxi10,
        p_id_producto_gas => v_gas_oxi_med,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2024::smallint,
        p_mes_fabricacion => ((v_i % 12) + 1)::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '6 months')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro demo DEV'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
      v_id_balon := (v_res->'registro'->>'id')::INT;
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'BALON',
        p_codigo_tipo_movimiento => 'ENTRADA_LLENADO',
        p_id_balon => v_id_balon,
        p_id_producto => v_gas_oxi_med,
        p_cantidad => 10,
        p_id_almacen_origen => v_alm_principal,
        p_id_almacen_destino => v_alm_principal,
        p_glosa => 'Carga inicial DEV (llenado)',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;

  -- Oxígeno industrial 6m³ × 4 (tipo industrial)
  SELECT id INTO v_tipo_oxi6 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Industrial 6 m³' AND estado = 1;
  FOR v_i IN 1..4 LOOP
    v_codigo := format('DEMO-OXI6-%s', lpad(v_i::text, 3, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_secundario,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_oxi6,
        p_id_producto_gas => v_gas_oxi_ind,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2022::smallint,
        p_mes_fabricacion => ((v_i % 12) + 1)::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '2 years')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro demo DEV industrial'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
      v_id_balon := (v_res->'registro'->>'id')::INT;
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'BALON',
        p_codigo_tipo_movimiento => 'ENTRADA_LLENADO',
        p_id_balon => v_id_balon,
        p_id_producto => v_gas_oxi_ind,
        p_cantidad => 6,
        p_id_almacen_origen => v_alm_secundario,
        p_id_almacen_destino => v_alm_secundario,
        p_glosa => 'Carga inicial DEV (llenado)',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;

  -- Acetileno × 3
  FOR v_i IN 1..3 LOOP
    v_codigo := format('DEMO-ACE5-%s', lpad(v_i::text, 3, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_principal,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_ace,
        p_id_producto_gas => v_gas_ace,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2023::smallint,
        p_mes_fabricacion => ((v_i % 12) + 1)::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '1 year')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro demo DEV acetileno'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
      v_id_balon := (v_res->'registro'->>'id')::INT;
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'BALON',
        p_codigo_tipo_movimiento => 'ENTRADA_LLENADO',
        p_id_balon => v_id_balon,
        p_id_producto => v_gas_ace,
        p_cantidad => 5,
        p_id_almacen_origen => v_alm_principal,
        p_id_almacen_destino => v_alm_principal,
        p_glosa => 'Carga inicial DEV (llenado)',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;

  -- Nitrógeno × 3 + 2 vacíos (sin llenado)
  FOR v_i IN 1..3 LOOP
    v_codigo := format('DEMO-NIT6-%s', lpad(v_i::text, 3, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_principal,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_nit,
        p_id_producto_gas => v_gas_nit,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2021::smallint,
        p_mes_fabricacion => ((v_i % 12) + 1)::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '18 months')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro demo DEV nitrógeno'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
      v_id_balon := (v_res->'registro'->>'id')::INT;
      v_res := inv_registrar_movimiento(
        p_naturaleza => 'BALON',
        p_codigo_tipo_movimiento => 'ENTRADA_LLENADO',
        p_id_balon => v_id_balon,
        p_id_producto => v_gas_nit,
        p_cantidad => 6,
        p_id_almacen_origen => v_alm_principal,
        p_id_almacen_destino => v_alm_principal,
        p_glosa => 'Carga inicial DEV (llenado)',
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;

  FOR v_i IN 1..2 LOOP
    v_codigo := format('DEMO-OXM6-VAC-%s', lpad(v_i::text, 2, '0'));
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE codigo_balon = v_codigo) THEN
      SELECT id INTO v_tipo_oxi6 FROM bal_tipo_balon WHERE nombre = 'Oxígeno Medicinal 6 m³' AND estado = 1;
      v_res := bal_crear_balon(
        p_codigo_balon => v_codigo,
        p_fecha_registro => CURRENT_DATE,
        p_id_almacen => v_alm_principal,
        p_id_propietario => v_prop_empresa,
        p_id_tipo_balon => v_tipo_oxi6,
        p_id_producto_gas => v_gas_oxi_med,
        p_id_estado_balon => v_estado_almacen,
        p_anio_fabricacion => 2020::smallint,
        p_mes_fabricacion => 3::smallint,
        p_numero_serie => v_codigo,
        p_id_marca_cilindro => v_marca,
        p_fecha_ultima_prueba_hidrostatica => (CURRENT_DATE - INTERVAL '3 years')::date,
        p_vigencia_prueba_hidrostatica_anios => 5,
        p_observacion => 'Cilindro vacío demo (sin gas en stock)'::varchar,
        p_id_usuario_auditoria => v_user
      );
      IF v_res->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_res->>'error'; END IF;
    END IF;
  END LOOP;
END $$;
