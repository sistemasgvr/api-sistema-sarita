-- Corrección puntual autorizada por el usuario. NO ejecutar automáticamente.
-- El cierre de la sesión 23 conserva S/1300 como EFECTIVO aunque los gastos
-- 97 y 98 ya tienen PROPIO - SR GC. Incluir también el cambio confirmado
-- del comprobante VSD01-00000112 (id 268), de crédito a efectivo por S/54.
-- Guardar previamente la fila completa de fin_caja_sesion con id=23.
-- Mantener los eventos originales del cierre como evidencia histórica.
BEGIN;

DO $correccion$
DECLARE
    s public.fin_caja_sesion%ROWTYPE;
    t jsonb;
    medios jsonb;
    propio jsonb;
    vivo jsonb;
    nota text := 'Ajuste autorizado 31/10/2026: S/1,300 de gastos reclasificados de efectivo a PROPIO - SR GC; VSD01-00000112, S/54 de credito a efectivo. Esperado anterior S/2,698.10; corregido S/4,052.10; contado S/4,052.10; diferencia S/0.00. Se conserva el evento original del cierre.';
BEGIN
    SELECT * INTO STRICT s FROM public.fin_caja_sesion WHERE id = 23 FOR UPDATE;
    t := s.totales_cierre::jsonb;
    IF s.fecha <> DATE '2026-10-30' OR s.id_sucursal <> 1
       OR s.fecha_cierre IS NULL OR s.estado <> 1
       OR s.monto_esperado <> 2698.10 OR s.diferencia <> 1354
       OR s.monto_efectivo_contado <> 4052.10
       OR (t->>'efectivoNeto')::numeric <> 2538.10
       OR (t->>'gastosCaja')::numeric <> 1576
       OR EXISTS (SELECT 1 FROM jsonb_array_elements(t->'porMedio') m
                  WHERE (m->>'idMedioPago')::integer = 441) THEN
        RAISE EXCEPTION 'El cierre cambió o ya fue corregido; revisar antes de continuar';
    END IF;

    IF (SELECT count(*) FROM public.fin_caja_gasto
        WHERE id IN (97,98) AND id_sesion=23 AND estado=1
          AND id_medio_pago=441 AND fecha=DATE '2026-10-30') <> 2
       OR (SELECT sum(monto) FROM public.fin_caja_gasto
           WHERE id IN (97,98)) <> 1300
       OR (SELECT sum(monto) FROM public.fin_caja_gasto
           WHERE id_sesion=23 AND estado=1) <> 1576 THEN
        RAISE EXCEPTION 'Los gastos cambiaron; revisar antes de continuar';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.ven_comprobante c
        WHERE c.id=268 AND c.serie='VSD01' AND c.numero='00000112'
          AND c.fecha=s.fecha AND c.id_sucursal=s.id_sucursal
          AND c.estado=1 AND c.total_importe=54 AND c.id_medio_pago=198)
       OR (SELECT sum(p.monto) FROM public.ven_pagos_de_comprobante(268) p
           WHERE p.id_medio_pago=198) IS DISTINCT FROM 54::numeric THEN
        RAISE EXCEPTION 'El comprobante de S/54 cambio; revisar antes de continuar';
    END IF;

    vivo := public.fin_caja_calcular_totales(s.fecha,s.id_sucursal)::jsonb;
    SELECT m INTO STRICT propio FROM jsonb_array_elements(vivo->'porMedio') m
    WHERE (m->>'idMedioPago')::integer=441;
    IF propio->>'medioPago' <> 'PROPIO - SR GC'
       OR (propio->>'gastos')::numeric <> 1300
       OR (propio->>'egresos')::numeric <> 1300
       OR (propio->>'ingresos')::numeric <> 0
       OR (propio->>'esEfectivo')::boolean
       OR (propio->>'afectaCaja')::boolean THEN
        RAISE EXCEPTION 'El medio propio cambió; revisar antes de continuar';
    END IF;

    IF (SELECT (m->>'gastos')::numeric
        FROM jsonb_array_elements(t->'porMedio') m
        WHERE (m->>'idMedioPago')::integer=198) IS DISTINCT FROM 1334::numeric THEN
        RAISE EXCEPTION 'El desglose de efectivo cambió';
    END IF;

    SELECT jsonb_agg(CASE WHEN (m->>'idMedioPago')::integer=198 THEN
        m || jsonb_build_object('gastos',34,'egresos',58.40,'neto',3892.10,
                               'ventas',3277.50,'ingresos',3950.50)
        ELSE m END ORDER BY posicion) INTO medios
    FROM jsonb_array_elements(t->'porMedio') WITH ORDINALITY a(m,posicion);

    t := t || jsonb_build_object(
        'porMedio', medios || jsonb_build_array(propio),
        'gastosCajaMediosCaja',276,
        'efectivoNeto',3892.10,
        'ventasContado',4627.50,
        'ventasCredito',1115,
        'ventasMediosCaja',3627.50,
        'ventasEfectivo',3277.50
    );
    IF t IS DISTINCT FROM vivo THEN
        RAISE EXCEPTION 'Hay otras diferencias ademas de los dos ajustes autorizados';
    END IF;
    IF length(concat_ws(E'\n',s.observacion_cierre,nota)) > 500 THEN
        RAISE EXCEPTION 'La explicacion excede el espacio de observaciones';
    END IF;
    UPDATE public.fin_caja_sesion SET
        totales_cierre=t::json,
        monto_esperado=4052.10,
        diferencia=0,
        observacion_cierre=concat_ws(E'\n',s.observacion_cierre,nota),
        fecha_modificacion=now()
    WHERE id=23;
END;
$correccion$;

SELECT id, monto_esperado, monto_efectivo_contado, diferencia, totales_cierre
FROM public.fin_caja_sesion WHERE id=23;

COMMIT;
