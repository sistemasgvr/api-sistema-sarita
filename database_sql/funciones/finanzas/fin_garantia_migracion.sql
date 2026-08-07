-- Migra la tabla fin_garantia al nuevo modelo (método de pago + campos de reembolso).
-- Idempotente.

-- Asegurar existencia de la tabla (si es primera vez)
CREATE TABLE IF NOT EXISTS fin_garantia (
    id                     SERIAL PRIMARY KEY,
    fecha                  DATE NOT NULL,
    id_cliente             INT NOT NULL REFERENCES cli_clientes(id),
    id_medio_pago          INT REFERENCES gen_lista_opciones(id),
    importe                NUMERIC(12,4) NOT NULL,
    observacion            VARCHAR(500),
    fecha_reembolso        DATE,
    id_medio_reembolso     INT REFERENCES gen_lista_opciones(id),
    observacion_reembolso  VARCHAR(500),
    id_usuario_reembolso   INT REFERENCES auth_usuarios(id),
    id_estado              INT REFERENCES gen_lista_opciones(id),
    estado                 INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion            TIMESTAMP DEFAULT NOW(),
    fecha_modificacion        TIMESTAMP DEFAULT NOW()
);

-- 1) Si la BD tenía la versión previa con id_medio_reembolso como método de pago,
--    lo renombramos a id_medio_pago y creamos uno nuevo vacío para el reembolso.
DO $$
BEGIN
    -- Si existe id_medio_reembolso pero no existe id_medio_pago → rename
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'fin_garantia' AND column_name = 'id_medio_reembolso'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'fin_garantia' AND column_name = 'id_medio_pago'
    ) THEN
        ALTER TABLE fin_garantia RENAME COLUMN id_medio_reembolso TO id_medio_pago;
    END IF;
END $$;

-- 2) Añadir las columnas nuevas si faltan
ALTER TABLE fin_garantia
    ADD COLUMN IF NOT EXISTS id_medio_pago         INT REFERENCES gen_lista_opciones(id),
    ADD COLUMN IF NOT EXISTS fecha_reembolso       DATE,
    ADD COLUMN IF NOT EXISTS id_medio_reembolso    INT REFERENCES gen_lista_opciones(id),
    ADD COLUMN IF NOT EXISTS observacion_reembolso VARCHAR(500),
    ADD COLUMN IF NOT EXISTS id_usuario_reembolso  INT REFERENCES auth_usuarios(id),
    ADD COLUMN IF NOT EXISTS id_estado             INT REFERENCES gen_lista_opciones(id);

-- 3) Marcar como ACTIVA cualquier garantía sin estado
UPDATE fin_garantia g
   SET id_estado = (
       SELECT glo.id FROM gen_lista_opciones glo
       JOIN gen_lista gl ON gl.id = glo.id_lista
       WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'ACTIVA'
       LIMIT 1
   )
 WHERE g.id_estado IS NULL AND g.estado = 1;
