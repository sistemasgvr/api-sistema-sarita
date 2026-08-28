-- ============================================================
-- Vínculo préstamo detalle ↔ GRE (guía de remisión) por FK
-- ============================================================
-- Hasta ahora el detalle de préstamo sólo guardaba serie/número de la guía como
-- texto libre, sin garantía de que la GRE exista. Se agregan las FK reales y se
-- mantienen serie/numero por compatibilidad con la UI actual (se sincronizan).

-- 1) Columnas de vínculo
ALTER TABLE bal_prestamo_detalle
    ADD COLUMN IF NOT EXISTS id_guia_entrega INT REFERENCES gre_guia_remision(id);

ALTER TABLE bal_prestamo_detalle
    ADD COLUMN IF NOT EXISTS id_guia_devolucion INT REFERENCES gre_guia_remision(id);

CREATE INDEX IF NOT EXISTS idx_bal_prestamo_detalle_guia_ent
    ON bal_prestamo_detalle(id_guia_entrega);

CREATE INDEX IF NOT EXISTS idx_bal_prestamo_detalle_guia_dev
    ON bal_prestamo_detalle(id_guia_devolucion);

-- 2) Backfill: resolver la GRE existente a partir de serie/número ya registrados.
--    Sólo cuando el par serie+numero identifica una única guía activa.
UPDATE bal_prestamo_detalle pd
SET id_guia_entrega = g.id
FROM gre_guia_remision g
WHERE pd.id_guia_entrega IS NULL
  AND NULLIF(TRIM(COALESCE(pd.serie_guia_entrega, '')), '') IS NOT NULL
  AND NULLIF(TRIM(COALESCE(pd.numero_guia_entrega, '')), '') IS NOT NULL
  AND g.estado = 1
  AND UPPER(TRIM(g.serie)) = UPPER(TRIM(pd.serie_guia_entrega))
  AND TRIM(g.numero) = TRIM(pd.numero_guia_entrega);

UPDATE bal_prestamo_detalle pd
SET id_guia_devolucion = g.id
FROM gre_guia_remision g
WHERE pd.id_guia_devolucion IS NULL
  AND NULLIF(TRIM(COALESCE(pd.serie_guia_devolucion, '')), '') IS NOT NULL
  AND NULLIF(TRIM(COALESCE(pd.numero_guia_devolucion, '')), '') IS NOT NULL
  AND g.estado = 1
  AND UPPER(TRIM(g.serie)) = UPPER(TRIM(pd.serie_guia_devolucion))
  AND TRIM(g.numero) = TRIM(pd.numero_guia_devolucion);

-- 3) Backfill de GRE automáticas POS: el préstamo apunta al comprobante y la GRE
--    lo referencia en gre_documentos_referencia, así que el vínculo es deducible
--    aunque el detalle nunca haya guardado serie/número.
UPDATE bal_prestamo_detalle pd
SET id_guia_entrega = v.id_guia_remision,
    serie_guia_entrega = COALESCE(pd.serie_guia_entrega, v.serie_guia),
    numero_guia_entrega = COALESCE(pd.numero_guia_entrega, v.numero_guia)
FROM (
    SELECT DISTINCT ON (p.id)
        p.id AS id_prestamo,
        g.id AS id_guia_remision,
        g.serie AS serie_guia,
        g.numero AS numero_guia
    FROM bal_prestamo p
    INNER JOIN ven_comprobante c ON c.id = p.id_comprobante_venta
    INNER JOIN gre_documentos_referencia r
        ON r.estado = 1
       AND (
           r.id_comprobante = c.id
           OR (
               r.id_comprobante IS NULL
               AND UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
               AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
           )
       )
    INNER JOIN gre_guia_remision g ON g.id = r.id_guia_remision AND g.estado = 1
    WHERE p.estado = 1
      AND p.id_comprobante_venta IS NOT NULL
    ORDER BY p.id, g.id
) v
WHERE pd.id_prestamo = v.id_prestamo
  AND pd.estado = 1
  AND pd.id_balon IS NOT NULL
  AND pd.id_guia_entrega IS NULL;

-- 4) Tras esta migración hay que re-aplicar los archivos de funciones afectados:
--      funciones/prestamos-detalle/bal_crear_prestamo_detalle.sql
--      funciones/prestamos-detalle/bal_actualizar_prestamo_detalle.sql
--      funciones/prestamos-detalle/bal_obtener_prestamo_detalle.sql
--      funciones/prestamos-detalle/bal_listar_prestamo_detalles.sql
--      funciones/comprobantes/ven_pos_crear_guia_remision.sql
--    Los dos primeros cambian de firma (dos parámetros nuevos al final) y ya
--    incluyen su propio DROP FUNCTION de la firma antigua para evitar overloads
--    ambiguos.
