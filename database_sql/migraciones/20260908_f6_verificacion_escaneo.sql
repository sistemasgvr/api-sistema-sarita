-- ============================================================
-- Migración: Fase 6 — verificación por escaneo, recojos y ranking
-- Fecha: 2026-09-08
-- Plan: admin-sistema-sarita/docs/plan-reestructuracion-oxigeno-sarita.md (Fase 6)
--
-- Apuntes 8.b.i.2 (detalle con referencia al origen y estados de verificación),
-- 8.b.i.3 (verificación por escaneo en salida y llegada), 8.b.i.4 (recojo con
-- estado del producto recogido) y 8.b.i.6 (ranking).
-- ============================================================

-- ------------------------------------------------------------
-- Catálogos
-- ------------------------------------------------------------

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('EstadoVerificacionItem', 'Resultado de verificar un ítem de actividad'),
        ('TipoOrigenActividad', 'De dónde nace la actividad: venta, orden de salida o préstamo'),
        ('EstadoProductoRecogido', 'Estado del producto al recogerlo en una visita')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Sin verificar'),
        ('OK', 'Verificado sin novedad'),
        ('CON_OBSERVACION', 'Verificado con observación')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoVerificacionItem'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('VENTA', 'Nace de un comprobante de venta'),
        ('ORDEN_SALIDA', 'Nace de un documento de salida'),
        ('PRESTAMO', 'Nace de un préstamo de cilindros')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoOrigenActividad'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('RECOGIDO', 'Recogido conforme'),
        ('NO_RECOGIDO', 'No se pudo recoger'),
        ('DANADO', 'Recogido con daño')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoProductoRecogido'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- ------------------------------------------------------------
-- Columnas nuevas
-- ------------------------------------------------------------

ALTER TABLE age_actividad
    ADD COLUMN IF NOT EXISTS id_prestamo INT NULL REFERENCES bal_prestamo(id),
    ADD COLUMN IF NOT EXISTS id_tipo_origen INT NULL REFERENCES gen_lista_opciones(id);

-- El ítem apunta al detalle que lo originó: así la entrega se carga por FK y no
-- se re-teclea, y al verificar se sabe qué línea de la orden se está mirando.
ALTER TABLE age_actividad_item
    ADD COLUMN IF NOT EXISTS id_venta_detalle INT NULL REFERENCES ven_comprobante_detalle(id),
    ADD COLUMN IF NOT EXISTS id_doc_salida_detalle INT NULL REFERENCES doc_salida_detalle(id),
    ADD COLUMN IF NOT EXISTS id_prestamo_detalle INT NULL REFERENCES bal_prestamo_detalle(id),
    ADD COLUMN IF NOT EXISTS id_estado_verificacion_salida INT NULL REFERENCES gen_lista_opciones(id),
    ADD COLUMN IF NOT EXISTS id_estado_verificacion_llegada INT NULL REFERENCES gen_lista_opciones(id),
    ADD COLUMN IF NOT EXISTS observacion_salida VARCHAR(500),
    ADD COLUMN IF NOT EXISTS observacion_llegada VARCHAR(500),
    ADD COLUMN IF NOT EXISTS id_estado_producto_recogido INT NULL REFERENCES gen_lista_opciones(id);

-- Bitácora de escaneos: queda el rastro de qué se leyó y si coincidía, aunque
-- después se corrija el estado del ítem a mano.
CREATE TABLE IF NOT EXISTS age_actividad_verificacion (
    id                       SERIAL PRIMARY KEY,
    id_actividad             INT NOT NULL REFERENCES age_actividad(id),
    id_actividad_item        INT NULL REFERENCES age_actividad_item(id),
    momento                  VARCHAR(10) NOT NULL,
    codigo_escaneado         VARCHAR(60) NOT NULL,
    coincide                 BOOLEAN NOT NULL DEFAULT FALSE,
    observacion              VARCHAR(500),
    fecha                    TIMESTAMP DEFAULT NOW(),
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW(),
    CONSTRAINT chk_age_verif_momento CHECK (momento IN ('SALIDA', 'LLEGADA'))
);

CREATE INDEX IF NOT EXISTS idx_age_verif_actividad ON age_actividad_verificacion(id_actividad);
CREATE INDEX IF NOT EXISTS idx_age_verif_item ON age_actividad_verificacion(id_actividad_item);
CREATE INDEX IF NOT EXISTS idx_age_item_doc_det ON age_actividad_item(id_doc_salida_detalle);
CREATE INDEX IF NOT EXISTS idx_age_item_prestamo_det ON age_actividad_item(id_prestamo_detalle);
CREATE INDEX IF NOT EXISTS idx_age_actividad_prestamo ON age_actividad(id_prestamo);

-- Los ítems que ya existen arrancan como pendientes de verificar.
UPDATE age_actividad_item ai
SET id_estado_verificacion_salida = (
        SELECT lo.id FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' LIMIT 1
    ),
    id_estado_verificacion_llegada = (
        SELECT lo.id FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' LIMIT 1
    )
WHERE ai.estado = 1
  AND ai.id_estado_verificacion_salida IS NULL;

-- ------------------------------------------------------------
-- Permisos
-- ------------------------------------------------------------

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('actividades.verificar', 'Verificar por escaneo los ítems de una actividad'),
        ('actividades.ranking', 'Ver el ranking de actividades por colaborador')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre IN ('actividades.verificar', 'actividades.ranking')
  AND NOT EXISTS (
      SELECT 1 FROM auth_roles_permisos rp WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
