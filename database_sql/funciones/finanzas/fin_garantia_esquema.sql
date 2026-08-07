-- ============================================================
-- Tabla fin_garantia — garantías dejadas por clientes al llevar
-- productos. Ciclo de vida:
--   1) RECEPCIÓN (crear): fecha, cliente, MÉTODO DE PAGO con que se recibió
--      el dinero, importe, observaciones → estado ACTIVA.
--   2) REEMBOLSO (opcional, posterior): fecha_reembolso, método de reembolso,
--      observaciones del reembolso → estado DEVUELTA.
-- ============================================================

CREATE TABLE IF NOT EXISTS fin_garantia (
    id                     SERIAL PRIMARY KEY,
    fecha                  DATE NOT NULL,
    id_cliente             INT NOT NULL REFERENCES cli_clientes(id),
    -- Método con el que el cliente PAGÓ la garantía
    id_medio_pago          INT REFERENCES gen_lista_opciones(id),
    importe                NUMERIC(12,4) NOT NULL,
    observacion            VARCHAR(500),
    -- Reembolso (opcional): se completa cuando se le devuelve al cliente
    fecha_reembolso        DATE,
    id_medio_reembolso     INT REFERENCES gen_lista_opciones(id),
    observacion_reembolso  VARCHAR(500),
    id_usuario_reembolso   INT REFERENCES auth_usuarios(id),
    -- Estado (usa lista EstadoGarantia): ACTIVA / DEVUELTA
    id_estado              INT REFERENCES gen_lista_opciones(id),
    estado                 INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion            TIMESTAMP DEFAULT NOW(),
    fecha_modificacion        TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fin_garantia_importe_positivo CHECK (importe > 0)
);

CREATE INDEX IF NOT EXISTS idx_fin_garantia_cliente_fecha ON fin_garantia(id_cliente, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_fin_garantia_estado ON fin_garantia(estado);
