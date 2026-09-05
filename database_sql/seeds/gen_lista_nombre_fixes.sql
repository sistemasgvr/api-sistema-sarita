-- Ajustes de nombres de catálogo para alinear con constantes del FE (ListaIds).
-- Idempotente.

-- FE espera "TipoSolicitud"; en prod/DEV quedó tipado "TIpoSolicitud"
UPDATE gen_lista
SET nombre = 'TipoSolicitud',
    fecha_modificacion = NOW()
WHERE id = 51
  AND nombre = 'TIpoSolicitud';

-- FE comentario decía "Banco"; en BD es "Bancos" (id 40). Se deja "Bancos".
-- (solo documentación en lista-ids.ts del admin)
