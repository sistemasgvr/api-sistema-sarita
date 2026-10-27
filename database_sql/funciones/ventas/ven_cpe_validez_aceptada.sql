-- Indica si la consulta de validez SUNAT de un comprobante coincide y está aceptada
DROP FUNCTION IF EXISTS public.ven_cpe_validez_aceptada (c ven_comprobante);

CREATE OR REPLACE FUNCTION public.ven_cpe_validez_aceptada (c ven_comprobante) RETURNS boolean LANGUAGE sql STABLE AS $function$
  SELECT COALESCE(
    c.validez_sunat->>'codigo' = '1'
    AND c.validez_sunat->'consulta'->>'numeroSerie' = c.serie
    AND c.validez_sunat->'consulta'->'numero' = to_jsonb(CASE WHEN c.numero ~ '^[0-9]+$' THEN c.numero::numeric ELSE 0 END)
    AND c.validez_sunat->'consulta'->'monto' = to_jsonb(c.total_importe)
    AND c.validez_sunat->'consulta'->>'fechaEmision' = to_char(COALESCE(c.fecha_emision_cpe, c.fecha::date), 'DD/MM/YYYY')
    AND c.validez_sunat->'consulta'->>'codComp' = (SELECT descripcion FROM gen_lista_opciones WHERE id=c.id_tipo_comprobante), false);
$function$;
