-- P0 money fixes: medio AJUSTE_NC + función updates aplicadas vía archivos fuente.
-- Aplicar también las funciones en database_sql/funciones/ (o re-sincronizar).

-- 1) Catálogo MedioPago: AJUSTE_NC (abono automático por nota de crédito)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'AJUSTE_NC', 'Abono automático por nota de crédito (no afecta caja)'
FROM gen_lista l
WHERE l.nombre = 'MedioPago'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND UPPER(lo.nombre) = 'AJUSTE_NC'
  );

INSERT INTO fin_medio_pago_config (
    id_medio_pago, es_efectivo, afecta_caja, requiere_cuenta_bancaria,
    requiere_numero_operacion, es_credito, orden
)
SELECT o.id, FALSE, FALSE, FALSE, FALSE, FALSE, 900
FROM gen_lista l
JOIN gen_lista_opciones o ON o.id_lista = l.id AND UPPER(o.nombre) = 'AJUSTE_NC'
WHERE l.nombre = 'MedioPago'
  AND NOT EXISTS (
      SELECT 1 FROM fin_medio_pago_config c WHERE c.id_medio_pago = o.id
  );

-- 2) Reaplicar funciones (contenido canónico en database_sql/funciones/):
--    - finanzas/fin_registrar_pago.sql
--    - finanzas/fin_abonar_por_nota_credito.sql
--    - finanzas/fin_listar_medios_pago.sql
--    - caja/fin_caja_calcular_totales.sql
--    - caja/fin_abrir_caja_sesion.sql
--    - garantias/ven_devolver_garantia.sql
