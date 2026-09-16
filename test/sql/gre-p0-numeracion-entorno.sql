-- Prueba de esquema y numeración GRE por empresa (plan GRE 16/09/2026, P0 #4 y #2).
-- Se ejecuta dentro de una transacción y termina en ROLLBACK: no deja datos.
-- Requiere aplicada database_sql/migraciones/20260916_gre_p0_fiscal_numeracion_entorno.sql.
BEGIN;

-- 1. Firmas y columnas que exige el backend.
DO $$
BEGIN
  PERFORM 'public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer, json, date)'::regprocedure;
  PERFORM 'public.gen_actualizar_empresa(integer, character varying, character varying, character varying, character varying, character varying, character varying, numeric, numeric, integer, integer)'::regprocedure;
  ASSERT (SELECT COUNT(*) FROM pg_proc WHERE proname = 'doc_convertir_a_gre') = 1, 'doc_convertir_a_gre con más de una firma';
  ASSERT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gen_empresa' AND column_name = 'id_distrito'), 'gen_empresa.id_distrito ausente';
  ASSERT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doc_gre_intento' AND column_name = 'entorno'), 'doc_gre_intento.entorno ausente';
  ASSERT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doc_gre_intento' AND column_name = 'proxima_consulta'), 'doc_gre_intento.proxima_consulta ausente';
  ASSERT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'uq_doc_salida_empresa_serie_numero'), 'índice por empresa+serie ausente';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'uq_doc_salida_serie_numero'), 'índice global por serie sigue vigente';
  RAISE NOTICE 'OK: esquema GRE P0';
END $$;

-- 2. Dos empresas con la misma serie reservan correlativos independientes.
DO $$
DECLARE
  v_emp_a integer; v_emp_b integer; v_dist integer;
  v_doc_a1 integer; v_doc_a2 integer;
  r json; r2 json;
  v_tipo integer;
BEGIN
  SELECT id INTO v_dist FROM gen_distrito WHERE codigo_ubigeo IS NOT NULL AND estado = 1 LIMIT 1;
  INSERT INTO gen_empresa (ruc, razon_social, direccion, id_distrito) VALUES ('20900000001', 'PRUEBA A', 'Dir A', v_dist) RETURNING id INTO v_emp_a;
  INSERT INTO gen_empresa (ruc, razon_social, direccion, id_distrito) VALUES ('20900000002', 'PRUEBA B', 'Dir B', v_dist) RETURNING id INTO v_emp_b;
  ASSERT (gen_obtener_empresa(v_emp_a)->'registro'->>'codigo_ubigeo') IS NOT NULL, 'gen_obtener_empresa no expone ubigeo';

  SELECT lo.id INTO v_tipo FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
  WHERE l.nombre = 'TipoGuiaRemision' AND TRIM(lo.descripcion) = '09' AND lo.estado = 1 LIMIT 1;

  -- Dos órdenes ya generadas (sin GRE): una para cada empresa.
  SELECT d.id INTO v_doc_a1 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
  WHERE d.estado = 1 AND d.serie IS NULL AND ec.nombre = 'GENERADA' AND NOT COALESCE(d.emitido_sunat, FALSE) ORDER BY d.id DESC LIMIT 1;
  ASSERT v_doc_a1 IS NOT NULL, 'No hay una orden GENERADA sin GRE para la prueba';
  SELECT d.id INTO v_doc_a2 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
  WHERE d.estado = 1 AND d.serie IS NULL AND ec.nombre = 'GENERADA' AND NOT COALESCE(d.emitido_sunat, FALSE) AND d.id <> v_doc_a1 ORDER BY d.id DESC LIMIT 1;
  IF v_doc_a2 IS NULL THEN
    v_doc_a2 := v_doc_a1;
    RAISE NOTICE 'Solo hay una orden disponible; se prueba únicamente la reserva de la empresa A';
  END IF;

  r := doc_convertir_a_gre(v_doc_a1, v_tipo, 'T999', p_fecha_traslado => CURRENT_DATE, p_id_empresa => v_emp_a, p_fecha_emision_gre => CURRENT_DATE);
  ASSERT r->>'error' IS NULL, 'convertir A1: ' || COALESCE(r->>'error', '');
  ASSERT (r->'registro'->>'numero_sunat') = '00000001', 'A1 debía ser 00000001, fue ' || (r->'registro'->>'numero_sunat');

  IF v_doc_a2 <> v_doc_a1 THEN
    r2 := doc_convertir_a_gre(v_doc_a2, v_tipo, 'T999', p_fecha_traslado => CURRENT_DATE, p_id_empresa => v_emp_b, p_fecha_emision_gre => CURRENT_DATE);
    ASSERT r2->>'error' IS NULL, 'convertir B1: ' || COALESCE(r2->>'error', '');
    ASSERT (r2->'registro'->>'numero_sunat') = '00000001', 'B debía numerar aparte (00000001), fue ' || (r2->'registro'->>'numero_sunat');
  END IF;

  RAISE NOTICE 'OK: numeración GRE independiente por empresa';
END $$;

ROLLBACK;
