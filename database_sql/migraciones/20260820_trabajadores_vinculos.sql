-- 1) Nuevas columnas + FKs
ALTER TABLE auth_usuarios
    ADD COLUMN IF NOT EXISTS id_trabajador INT REFERENCES tra_trabajadores(id);

ALTER TABLE gen_chofer
    ADD COLUMN IF NOT EXISTS id_trabajador INT REFERENCES tra_trabajadores(id);

-- El nombre del chofer de flota propia se resuelve desde el trabajador (id_trabajador)
ALTER TABLE gen_chofer ALTER COLUMN nombres DROP NOT NULL;

ALTER TABLE age_actividad
    ADD COLUMN IF NOT EXISTS id_trabajador_responsable INT REFERENCES tra_trabajadores(id);

-- 2) Backfill: usuarios -> trabajador (desde tra_trabajadores.id_usuario)
UPDATE auth_usuarios au
SET id_trabajador = t.id
FROM tra_trabajadores t
WHERE t.id_usuario = au.id
  AND au.id_trabajador IS NULL;

-- 3) Backfill: choferes -> trabajador (desde tra_trabajadores.id_chofer)
UPDATE gen_chofer c
SET id_trabajador = t.id
FROM tra_trabajadores t
WHERE t.id_chofer = c.id
  AND c.id_trabajador IS NULL;

-- 4) Backfill: choferes de flota propia sin trabajador -> crear el trabajador
DO $$
DECLARE
    r RECORD;
    v_id INT;
BEGIN
    FOR r IN
        SELECT
            c.id AS chofer_id,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            c.numero_documento,
            c.telefono,
            c.id_usuario_creacion
        FROM gen_chofer c
        WHERE c.id_cliente IS NULL
          AND c.estado = 1
          AND c.id_trabajador IS NULL
    LOOP
        INSERT INTO tra_trabajadores (
            nombres, apellido_paterno, apellido_materno,
            id_tipo_documento, numero_documento,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            r.nombres, r.apellido_paterno, r.apellido_materno,
            r.id_tipo_documento, r.numero_documento,
            1, r.id_usuario_creacion, r.id_usuario_creacion
        )
        RETURNING id INTO v_id;

        UPDATE gen_chofer SET id_trabajador = v_id WHERE id = r.chofer_id;
    END LOOP;
END $$;

-- 5) Backfill: actividades -> trabajador responsable (desde usuario o chofer)
UPDATE age_actividad a
SET id_trabajador_responsable = u.id_trabajador
FROM auth_usuarios u
WHERE a.id_trabajador_responsable IS NULL
  AND a.id_usuario_responsable IS NOT NULL
  AND u.id = a.id_usuario_responsable
  AND u.id_trabajador IS NOT NULL;

UPDATE age_actividad a
SET id_trabajador_responsable = c.id_trabajador
FROM gen_chofer c
WHERE a.id_trabajador_responsable IS NULL
  AND a.id_chofer_responsable IS NOT NULL
  AND c.id = a.id_chofer_responsable
  AND c.id_trabajador IS NOT NULL;

-- 6) Eliminar columnas obsoletas de tra_trabajadores
ALTER TABLE tra_trabajadores DROP COLUMN IF EXISTS id_usuario;
ALTER TABLE tra_trabajadores DROP COLUMN IF EXISTS id_chofer;

-- 7) Índices
CREATE INDEX IF NOT EXISTS idx_auth_usuarios_trabajador
    ON auth_usuarios(id_trabajador) WHERE id_trabajador IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gen_chofer_trabajador
    ON gen_chofer(id_trabajador) WHERE id_trabajador IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_age_actividad_trabajador
    ON age_actividad(id_trabajador_responsable) WHERE id_trabajador_responsable IS NOT NULL;
