-- ============================================================
-- Migración: Recojo de recarga en planta externa (balones con proveedor)
-- Fecha: 2026-08-28
-- ============================================================

-- 1) Nuevo estado de contenido SEMILLLENO
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('SEMILLLENO', 'Semi-lleno (gas parcial recibido en recojo de planta)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoContenidoBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- 2) Columnas en bal_recojo para origen recarga en planta / compra
ALTER TABLE bal_recojo
    ADD COLUMN IF NOT EXISTS id_recarga_planta INT NULL REFERENCES bal_recarga_planta(id);

ALTER TABLE bal_recojo
    ADD COLUMN IF NOT EXISTS id_compra INT NULL REFERENCES com_comprobante_compra(id);

-- 3) Detalle de recojo puede referenciar un balón directamente (origen recarga planta)
ALTER TABLE bal_recojo_detalle
    ADD COLUMN IF NOT EXISTS id_balon INT NULL REFERENCES bal_balon(id);

ALTER TABLE bal_recojo_detalle
    ALTER COLUMN id_prestamo_detalle DROP NOT NULL;

-- La restricción única original (id_recojo, id_prestamo_detalle) permitía NULLs duplicados
-- y no cubría los nuevos orígenes. La reemplazamos por un índice único con expresiones
-- (las restricciones UNIQUE no aceptan COALESCE).
ALTER TABLE bal_recojo_detalle
    DROP CONSTRAINT IF EXISTS uq_bal_recojo_detalle_unico;

ALTER TABLE bal_recojo_detalle
    DROP CONSTRAINT IF EXISTS bal_recojo_detalle_id_recojo_id_prestamo_detalle_key;

DROP INDEX IF EXISTS uq_bal_recojo_detalle_unico;

CREATE UNIQUE INDEX IF NOT EXISTS uq_bal_recojo_detalle_unico
    ON bal_recojo_detalle (
        id_recojo,
        COALESCE(id_prestamo_detalle, id_alquiler_detalle),
        COALESCE(id_balon, 0)
    );

CREATE INDEX IF NOT EXISTS idx_bal_recojo_recarga_planta
    ON bal_recojo(id_recarga_planta);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_compra
    ON bal_recojo(id_compra);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_det_balon
    ON bal_recojo_detalle(id_balon);
