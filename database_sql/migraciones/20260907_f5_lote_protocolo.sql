-- ============================================================
-- Migración: Fase 5 — Oxígeno medicinal, lote y protocolo con historial
-- Fecha: 2026-09-07
-- Plan: admin-sistema-sarita/docs/plan-reestructuracion-oxigeno-sarita.md (Fase 5)
--
-- Registra la ficha ICP de la planta (Anexo A del plan): cabecera, datos de
-- análisis y relación de envases aprobados. Cada recarga de O2 medicinal queda
-- ligada a la ficha vigente, y el balón guarda cuál es la última que se le aplicó.
-- ============================================================

-- ------------------------------------------------------------
-- Tablas
-- ------------------------------------------------------------

-- Cabecera de la ficha ICP ("Protocolo de Análisis Cilindros").
CREATE TABLE IF NOT EXISTS bal_lote_protocolo (
    id                       SERIAL PRIMARY KEY,
    numero_lote              VARCHAR(60) NOT NULL,
    numero_protocolo         VARCHAR(30) NULL,
    id_proveedor             INT NULL REFERENCES cli_clientes(id),
    id_producto_gas          INT NULL REFERENCES pro_producto(id),
    descripcion_producto     VARCHAR(250) NULL,
    forma_farmaceutica       VARCHAR(80) NULL,
    presentacion             VARCHAR(150) NULL,
    norma_tecnica            VARCHAR(80) NULL,
    metodo_fabricacion       VARCHAR(150) NULL,
    fecha_analisis           DATE NULL,
    fecha_emision            DATE NULL,
    fecha_fabricacion        DATE NULL,
    -- La ficha trae mes/año ("08/2027"); se guarda como el día 1 de ese mes.
    fecha_vencimiento        DATE NULL,
    tamano_lote_m3           NUMERIC(12,2) NULL,
    cantidad_envases         INT NULL,
    valoracion_o2_pct        NUMERIC(6,3) NULL,
    -- NULL = "N.A." en la ficha (el O2 por licuefacción está exento).
    limite_co2_ppm           NUMERIC(10,3) NULL,
    limite_co_ppm            NUMERIC(10,3) NULL,
    cilindro_muestreado_serie VARCHAR(60) NULL,
    temperatura_muestreo_c   NUMERIC(6,2) NULL,
    presion_muestreo_psi     NUMERIC(10,2) NULL,
    analista                 VARCHAR(150) NULL,
    conclusion               VARCHAR(500) NULL,
    codigo_documento         VARCHAR(40) NULL,
    version_documento        VARCHAR(10) NULL,
    id_archivo_pdf           INT NULL REFERENCES gen_archivo(id),
    observacion              VARCHAR(500) NULL,
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- Filas de "DATOS DE ANÁLISIS" (Prueba / Especificación / Resultado).
CREATE TABLE IF NOT EXISTS bal_lote_protocolo_prueba (
    id                       SERIAL PRIMARY KEY,
    id_lote_protocolo        INT NOT NULL REFERENCES bal_lote_protocolo(id),
    orden                    INT NOT NULL DEFAULT 0,
    prueba                   VARCHAR(120) NOT NULL,
    especificacion           VARCHAR(300) NULL,
    resultado                VARCHAR(120) NULL,
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- "RELACIÓN DE ENVASES APROBADOS": ~60 series por lote. id_balon se resuelve
-- contra bal_balon.numero_serie cuando el envase existe en el sistema; queda
-- NULL si la planta incluyó un envase que nosotros no tenemos registrado.
CREATE TABLE IF NOT EXISTS bal_lote_protocolo_envase (
    id                       SERIAL PRIMARY KEY,
    id_lote_protocolo        INT NOT NULL REFERENCES bal_lote_protocolo(id),
    serie_envase             VARCHAR(60) NOT NULL,
    id_balon                 INT NULL REFERENCES bal_balon(id),
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_lote_protocolo, serie_envase)
);

-- Historial por recarga: cada recarga referencia la ficha vigente en ese momento.
ALTER TABLE bal_movimiento_recarga
    ADD COLUMN IF NOT EXISTS id_lote_protocolo INT NULL REFERENCES bal_lote_protocolo(id);

-- La recarga en planta externa vive en doc_salida desde la Fase 2; ahí también
-- se registra la ficha con la que volvieron los cilindros.
ALTER TABLE doc_salida
    ADD COLUMN IF NOT EXISTS id_lote_protocolo INT NULL REFERENCES bal_lote_protocolo(id);

-- Última ficha aplicada al cilindro (atajo para el detalle del balón).
ALTER TABLE bal_balon
    ADD COLUMN IF NOT EXISTS id_lote_protocolo_vigente INT NULL REFERENCES bal_lote_protocolo(id);

CREATE INDEX IF NOT EXISTS idx_bal_lote_protocolo_numero ON bal_lote_protocolo(numero_lote);
CREATE INDEX IF NOT EXISTS idx_bal_lote_protocolo_proveedor ON bal_lote_protocolo(id_proveedor);
CREATE INDEX IF NOT EXISTS idx_bal_lote_protocolo_gas ON bal_lote_protocolo(id_producto_gas);
CREATE INDEX IF NOT EXISTS idx_bal_lote_protocolo_venc ON bal_lote_protocolo(fecha_vencimiento);
CREATE INDEX IF NOT EXISTS idx_bal_lp_prueba_cab ON bal_lote_protocolo_prueba(id_lote_protocolo);
CREATE INDEX IF NOT EXISTS idx_bal_lp_envase_cab ON bal_lote_protocolo_envase(id_lote_protocolo);
CREATE INDEX IF NOT EXISTS idx_bal_lp_envase_balon ON bal_lote_protocolo_envase(id_balon);
CREATE INDEX IF NOT EXISTS idx_bal_lp_envase_serie ON bal_lote_protocolo_envase(serie_envase);
CREATE INDEX IF NOT EXISTS idx_bal_mov_recarga_lote ON bal_movimiento_recarga(id_lote_protocolo);
CREATE INDEX IF NOT EXISTS idx_doc_salida_lote ON doc_salida(id_lote_protocolo);
CREATE INDEX IF NOT EXISTS idx_bal_balon_lote_vigente ON bal_balon(id_lote_protocolo_vigente);

-- Un mismo número de lote no se repite por proveedor mientras esté activo.
CREATE UNIQUE INDEX IF NOT EXISTS uq_bal_lote_protocolo_activo
    ON bal_lote_protocolo(numero_lote, COALESCE(id_proveedor, 0))
    WHERE estado = 1;

-- ------------------------------------------------------------
-- Permisos
-- ------------------------------------------------------------

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('lotes_protocolo.listar', 'Listar fichas de lote y protocolo (ICP)'),
        ('lotes_protocolo.ver', 'Ver detalle de ficha de lote y protocolo'),
        ('lotes_protocolo.crear', 'Registrar fichas de lote y protocolo'),
        ('lotes_protocolo.editar', 'Editar fichas de lote y protocolo'),
        ('lotes_protocolo.eliminar', 'Eliminar fichas de lote y protocolo')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'lotes_protocolo.%'
  AND NOT EXISTS (
      SELECT 1 FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
