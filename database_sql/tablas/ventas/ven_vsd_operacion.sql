-- Append-only business history. No existing sales/inventory are rewritten by this migration.
CREATE TABLE IF NOT EXISTS public.ven_vsd_operacion (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_comprobante integer NOT NULL REFERENCES ven_comprobante(id),
    tipo varchar(20) NOT NULL CHECK (tipo IN ('CORRECCION', 'CAMBIO_BALON')),
    solicitud uuid UNIQUE,
    motivo varchar(500) NOT NULL CHECK (length(btrim(motivo)) >= 5),
    datos jsonb NOT NULL,
    anterior jsonb NOT NULL,
    posterior jsonb NOT NULL,
    id_usuario integer NOT NULL REFERENCES auth_usuarios(id),
    fecha timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vsd_operacion_venta ON ven_vsd_operacion(id_comprobante, id);
