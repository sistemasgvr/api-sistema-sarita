-- Run ONLY against the restored Docker snapshot using vsd-local.js.
-- Requiere aplicado database_sql/migraciones/sync-prod-desde-dev.sql (incluye fin_caja_sesion_evento
-- y las funciones de caja; antes en la migración suelta 20261026_caja_sesion_evento.sql, ya retirada).
-- Todo el fixture y las operaciones se revierten (ROLLBACK al final).
BEGIN;
CREATE TEMP TABLE caja_results(label text);
CREATE FUNCTION pg_temp.ok(condition boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO caja_results VALUES(label);
END $$;

DO $$
DECLARE
  v_usuario integer;
  v_sucursal integer;
  v_fecha date := CURRENT_DATE + 30;
  v_abierta integer;
  v_id integer;
  v_result json;
  v_item json;
BEGIN
  SELECT min(id) INTO v_usuario FROM auth_usuarios WHERE estado = true;
  SELECT min(id) INTO v_sucursal FROM gen_sucursal;
  SELECT lo.id INTO v_abierta FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA' LIMIT 1;
  PERFORM pg_temp.ok(v_usuario IS NOT NULL AND v_sucursal IS NOT NULL AND v_abierta IS NOT NULL, 'Fixture: usuario, sucursal y estado ABIERTA');

  -- Saca de juego (solo dentro de la transacción) la sesión de esa fecha y cualquier
  -- caja abierta de la sucursal, que bloquearían la apertura. Baja lógica (estado = 0)
  -- en vez de DELETE para no chocar con gastos/depósitos que referencien la sesión.
  UPDATE fin_caja_sesion SET estado = 0
  WHERE estado = 1 AND COALESCE(id_sucursal, 0) = v_sucursal
    AND (fecha = v_fecha OR id_estado = v_abierta);

  -- abrir (monto 100, 'apertura A')
  v_result := fin_abrir_caja_sesion(v_fecha, 100, v_sucursal, 'apertura A', v_usuario, NULL::integer);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'abrir sin error');
  v_id := (v_result->'registro'->>'id')::integer;
  PERFORM pg_temp.ok(v_id IS NOT NULL, 'abrir devuelve id');

  -- cerrar (contado 100, 'cierre A')
  v_result := fin_cerrar_caja_sesion(v_id, 100, 'cierre A', v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'cerrar A sin error');

  -- reabrir (p_id_sesion, monto 100, 'reapertura B')
  v_result := fin_abrir_caja_sesion(v_fecha, 100, v_sucursal, 'reapertura B', v_usuario, v_id);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'reabrir sin error');

  -- cerrar (contado 90, 'cierre B')
  v_result := fin_cerrar_caja_sesion(v_id, 90, 'cierre B', v_usuario);
  PERFORM pg_temp.ok(v_result->>'error' IS NULL, 'cerrar B sin error');

  PERFORM pg_temp.ok((SELECT count(*) FROM fin_caja_sesion_evento WHERE id_sesion = v_id) = 4, '4 eventos');
  PERFORM pg_temp.ok((SELECT array_agg(tipo ORDER BY fecha_hora, id) FROM fin_caja_sesion_evento WHERE id_sesion = v_id)
                     = ARRAY['ABRIR','CERRAR','REABRIR','CERRAR']::varchar[], 'orden de tipos');
  PERFORM pg_temp.ok(EXISTS (SELECT 1 FROM fin_caja_sesion_evento WHERE id_sesion = v_id AND observacion = 'apertura A'), 'no se pierde apertura A');
  PERFORM pg_temp.ok(EXISTS (SELECT 1 FROM fin_caja_sesion_evento WHERE id_sesion = v_id AND tipo = 'CERRAR' AND observacion = 'cierre A'), 'no se pierde cierre A');
  PERFORM pg_temp.ok((SELECT diferencia FROM fin_caja_sesion_evento WHERE id_sesion = v_id AND tipo = 'CERRAR' ORDER BY id DESC LIMIT 1) = -10, 'diferencia del último cierre');
  PERFORM pg_temp.ok((SELECT id_usuario FROM fin_caja_sesion_evento WHERE id_sesion = v_id AND tipo = 'REABRIR') = v_usuario, 'reabrir guarda usuario');
  PERFORM pg_temp.ok((SELECT observacion_apertura FROM fin_caja_sesion WHERE id = v_id) = 'reapertura B', 'sesión guarda último comentario');

  -- fin_obtener_caja_sesion → registro.eventos
  v_result := fin_obtener_caja_sesion(v_id);
  PERFORM pg_temp.ok(json_array_length((v_result->'registro')->'eventos') = 4, 'obtener devuelve eventos');
  PERFORM pg_temp.ok(((v_result->'registro')->'eventos'->0->>'tipo') = 'ABRIR'
                     AND ((v_result->'registro')->'eventos'->3->>'tipo') = 'CERRAR'
                     AND ((v_result->'registro')->'eventos'->3->>'diferencia')::numeric = -10
                     AND ((v_result->'registro')->'eventos'->0->>'usuario') IS NOT NULL
                     AND ((v_result->'registro')->'eventos'->0->>'fechaHora') IS NOT NULL,
                     'obtener: forma de eventos (tipo, diferencia, usuario, fechaHora)');

  -- fin_obtener_caja_dia delega en fin_obtener_caja_sesion
  v_result := fin_obtener_caja_dia(v_fecha, v_sucursal);
  PERFORM pg_temp.ok(json_array_length((v_result->'registro')->'eventos') = 4, 'caja/dia devuelve eventos');

  -- fin_listar_caja_sesiones → registros[] con observaciones y cantidadEventos
  v_result := fin_listar_caja_sesiones(v_fecha, v_fecha, v_sucursal, NULL, 20, 0);
  SELECT r INTO v_item FROM json_array_elements(v_result->'registros') r WHERE (r->>'id')::integer = v_id;
  PERFORM pg_temp.ok(v_item IS NOT NULL, 'listar incluye la sesión');
  PERFORM pg_temp.ok(v_item->>'observacionCierre' = 'cierre B', 'listar: observacionCierre');
  PERFORM pg_temp.ok(v_item->>'observacionApertura' = 'reapertura B', 'listar: observacionApertura');
  PERFORM pg_temp.ok((v_item->>'cantidadEventos')::integer = 4, 'listar: cantidadEventos');
END $$;

SELECT 'PASS '||label FROM caja_results;
SELECT 'TOTAL '||count(*) FROM caja_results;
ROLLBACK;
