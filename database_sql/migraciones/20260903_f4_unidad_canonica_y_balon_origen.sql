-- Decisiones 3 y 16 del plan (docs/plan-reestructuracion-oxigeno-sarita.md).
--
--  3. Unidad canónica del stock de gas -> la del PRODUCTO (pro_producto.id_unidad_medida).
--     bal_tipo_balon puede estar catalogado en otra unidad (hoy: 4 tipos de Acetileno y
--     4 de Dióxido de Carbono en MT3 con el gas en KG). Esa cantidad llegaba tal cual a
--     pro_stock y mezclaba kilos con metros cúbicos en un mismo saldo.
--     Se convierte en el borde; NO se reescriben las capacidades de los tipos, porque es
--     legítimo que un cilindro esté rateado en m³ aunque el gas se venda por kilo.
--
-- 16. "Balón origen" pasa a ser SOLO TRAZABILIDAD. El gas se controla en el stock global
--     del almacén; ya no existe saldo por cilindro. Se eliminan las funciones que
--     calculaban/consumían capacidad por balón (quedaron sin persistencia tras dropear
--     bal_balon.capacidad_restante en la Fase 1) y el filtro "> 0" que, al devolver la
--     capacidad nominal del tipo, era siempre verdadero y listaba cilindros vacíos.
--
-- Este archivo solo contiene DDL. Los CUERPOS de función viven en database_sql/funciones/
-- y se aplican con:
--     node database_sql/scripts/rebuild-schema-from-repo.js --functions
-- (No se incrustan aquí: fue justamente lo que dejó irreejecutables las migraciones de F1.)

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. Funciones de capacidad por cilindro: sin persistencia y sin llamadores vivos.
--     La validación real de disponibilidad la hace bal_asignar_origenes_recarga
--     contra inv_stock_producto (pro_stock).
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
            'bal_capacidad_disponible_balon',
            'bal_consumir_capacidad_balon_origen',
            'bal_consumir_capacidad_origenes_recarga'
          )
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
    END LOOP;
END $$;

COMMIT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verificación posterior (informativa, no falla la migración).
-- Tipos de balón cuya unidad difiere de la de su gas: seguirán funcionando gracias a
-- inv_convertir_a_unidad_producto, pero conviene revisarlos con operaciones.
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT tb.nombre AS tipo, umt.nombre AS unidad_tipo, p.nombre AS gas, ump.nombre AS unidad_gas
-- FROM bal_tipo_balon tb
-- JOIN pro_producto p ON p.id = tb.id_gas
-- LEFT JOIN gen_lista_opciones umt ON umt.id = tb.id_unidad_medida
-- LEFT JOIN gen_lista_opciones ump ON ump.id = p.id_unidad_medida
-- WHERE tb.estado = 1 AND COALESCE(umt.nombre,'') <> COALESCE(ump.nombre,'');
