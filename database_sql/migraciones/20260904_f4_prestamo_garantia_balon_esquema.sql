-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
--
-- Fase 4 (apunte 1.c.viii) — esquema para "préstamo con garantía de balón": el
-- cliente deja su cilindro como colateral y se lleva uno de Sarita recargado.
--
-- Nota de diseño: el plan de fases pedía originalmente una columna nueva
-- bal_balon.origen_registro (EMPRESA|GARANTIA_CLIENTE). Al revisar el esquema
-- real se confirmó que bal_balon.id_propietario YA es un FK a
-- gen_lista_opciones/PropietarioBalon (EMPRESA, CLIENTE, PROPIA, PLANTA) —
-- exactamente el mismo propósito. En vez de una columna redundante, se agrega
-- una opción nueva 'GARANTIA_CLIENTE' a ese catálogo existente y se usa
-- id_propietario para el balón de garantía. Sin ALTER en bal_balon.
--
-- Sí son nuevas (confirmado, cero referencias en todo el repo):
--   - bal_prestamo_detalle.rol (ENTREGADO | GARANTIA) — hoy toda fila es
--     indiferenciada; con esto un mismo préstamo puede tener el cilindro
--     entregado al cliente Y el cilindro que dejó en garantía, enlazados al
--     mismo id_prestamo.
--   - bal_prestamo.id_prestamo_origen (self-FK) — encadena renovaciones
--     (apunte 1.c.ix, Paso 5 del plan), no se usa todavía en este paso.
--
-- Ambas columnas nuevas llevan DEFAULT retrocompatible: cero filas existentes
-- cambian de significado.

ALTER TABLE bal_prestamo_detalle
    ADD COLUMN IF NOT EXISTS rol character varying(20) NOT NULL DEFAULT 'ENTREGADO'
    CHECK (rol IN ('ENTREGADO', 'GARANTIA'));

ALTER TABLE bal_prestamo
    ADD COLUMN IF NOT EXISTS id_prestamo_origen integer;

ALTER TABLE bal_prestamo
    DROP CONSTRAINT IF EXISTS bal_prestamo_id_prestamo_origen_fkey;

ALTER TABLE bal_prestamo
    ADD CONSTRAINT bal_prestamo_id_prestamo_origen_fkey
    FOREIGN KEY (id_prestamo_origen) REFERENCES bal_prestamo(id);

-- Catálogo: nueva opción de propietario para el balón que el cliente deja en garantía.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'GARANTIA_CLIENTE', 'Garantía de cliente (préstamo de balón)'
FROM gen_lista l
WHERE l.nombre = 'PropietarioBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'GARANTIA_CLIENTE'
  );

-- Catálogo: nuevo tipo de movimiento de balón para la entrada física del cilindro
-- de garantía a custodia de Sarita. No requiere tocar inv_signo_tipo_movimiento.sql:
-- ya tiene una regla comodín "v_nombre LIKE 'ENTRADA_%'" que trata cualquier código
-- con ese prefijo como ingreso.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'ENTRADA_GARANTIA', 'Entrada garantía de cliente'
FROM gen_lista l
WHERE l.nombre = 'TipoMovBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'ENTRADA_GARANTIA'
  );
