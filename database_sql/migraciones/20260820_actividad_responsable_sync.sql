CREATE OR REPLACE FUNCTION age_sync_responsable_trabajador()
RETURNS TRIGGER AS $function$
BEGIN
  IF NEW.id_trabajador_responsable IS NOT NULL THEN
    SELECT c.id
    INTO NEW.id_chofer_responsable
    FROM gen_chofer c
    WHERE c.id_trabajador = NEW.id_trabajador_responsable
      AND c.id_cliente IS NULL
      AND c.estado = 1
    LIMIT 1;

    SELECT u.id
    INTO NEW.id_usuario_responsable
    FROM auth_usuarios u
    WHERE u.id_trabajador = NEW.id_trabajador_responsable
      AND u.estado = TRUE
    LIMIT 1;
  ELSE
    NEW.id_chofer_responsable := NULL;
    NEW.id_usuario_responsable := NULL;
  END IF;

  RETURN NEW;
END;
$function$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_age_sync_responsable ON age_actividad;

CREATE TRIGGER trg_age_sync_responsable
  BEFORE INSERT OR UPDATE ON age_actividad
  FOR EACH ROW
  EXECUTE FUNCTION age_sync_responsable_trabajador();
