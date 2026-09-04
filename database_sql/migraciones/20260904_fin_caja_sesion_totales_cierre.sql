-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
--
-- Parte A del diseño de "caja histórica inmutable + devolución fechada hoy":
--
-- fin_obtener_caja_sesion recalcula fin_caja_calcular_totales(fecha, sucursal) EN VIVO
-- cada vez que se abre CUALQUIER sesión — abierta o ya cerrada. Solo el agregado final
-- (monto_esperado, diferencia) queda congelado al cerrar; el desglose detallado
-- (ventasContado, ventasCredito, garantías, etc. — las cards que muestra CajaView.vue)
-- se recomputa siempre. Eso significa que CUALQUIER cambio futuro a una venta de un día
-- ya cerrado (anularla, corregirla, etc.) altera en silencio lo que esa caja cerrada
-- muestra al reabrirla — exactamente el riesgo que motivó esta migración: "podríamos
-- eliminar una venta de una caja de días atrás y el monto de esa caja disminuye".
--
-- Este ALTER agrega la columna donde fin_cerrar_caja_sesion va a guardar el JSON
-- completo de fin_caja_calcular_totales() en el momento exacto del cierre, para que
-- fin_obtener_caja_sesion pueda servir esa foto congelada en vez de recalcular cuando
-- la sesión ya está cerrada. Ver 20260904_fin_cerrar_caja_sesion_totales_cierre.sql y
-- 20260904_fin_obtener_caja_sesion_totales_congeladas.sql (aplicar los tres juntos).

ALTER TABLE fin_caja_sesion ADD COLUMN IF NOT EXISTS totales_cierre json;
