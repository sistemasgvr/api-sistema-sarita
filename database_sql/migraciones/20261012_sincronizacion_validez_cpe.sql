BEGIN;

ALTER TABLE ven_comprobante ADD COLUMN IF NOT EXISTS validez_sunat jsonb;

-- La evidencia deja de ser aplicable si cambian los datos del CPE.
CREATE OR REPLACE FUNCTION ven_cpe_validez_aceptada(c ven_comprobante)
RETURNS boolean LANGUAGE sql STABLE AS $body$
  SELECT COALESCE(
    c.validez_sunat->>'codigo' = '1'
    AND c.validez_sunat->'consulta'->>'numeroSerie' = c.serie
    AND c.validez_sunat->'consulta'->'numero' = to_jsonb(CASE WHEN c.numero ~ '^[0-9]+$' THEN c.numero::numeric ELSE 0 END)
    AND c.validez_sunat->'consulta'->'monto' = to_jsonb(c.total_importe)
    AND c.validez_sunat->'consulta'->>'fechaEmision' = to_char(COALESCE(c.fecha_emision_cpe, c.fecha::date), 'DD/MM/YYYY')
    AND c.validez_sunat->'consulta'->>'codComp' = (SELECT descripcion FROM gen_lista_opciones WHERE id=c.id_tipo_comprobante), false);
$body$;

-- Conserva la definición instalada y evita que una respuesta tardía de emisión
-- borre una aceptación ya verificada directamente con SUNAT.
DO $migration$
DECLARE definition text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO STRICT definition
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='ven_registrar_respuesta_sunat';
  definition := replace(definition, chr(13) || chr(10), chr(10));
  IF position('ven_cpe_validez_aceptada' IN definition)=0 THEN
    IF position('    UPDATE ven_comprobante' IN definition)=0 THEN
      RAISE EXCEPTION 'Definición inesperada de ven_registrar_respuesta_sunat';
    END IF;
    definition := replace(definition, '    UPDATE ven_comprobante' || chr(10) || '    SET',
      '    PERFORM 1 FROM ven_comprobante WHERE id=p_id FOR UPDATE;' || chr(10) ||
      '    IF v_estado_sunat_nombre IN (''PENDIENTE'', ''RECHAZADO'') AND EXISTS (' || chr(10) ||
      '        SELECT 1 FROM ven_comprobante c WHERE c.id=p_id AND ven_cpe_validez_aceptada(c)' || chr(10) ||
      '    ) THEN RETURN ven_obtener_comprobante(p_id); END IF;' || chr(10) ||
      '    UPDATE ven_comprobante' || chr(10) || '    SET');
    IF position('ven_cpe_validez_aceptada' IN definition)=0 THEN
      RAISE EXCEPTION 'No se pudo instalar protección de respuesta tardía';
    END IF;
    EXECUTE definition;
  END IF;
END;
$migration$;

COMMIT;
