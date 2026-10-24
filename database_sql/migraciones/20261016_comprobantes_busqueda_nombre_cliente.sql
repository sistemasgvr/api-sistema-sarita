BEGIN;

-- Incluye personas naturales: las boletas suelen tener nombres/apellidos
-- en lugar de razón social. Parchea la función instalada para conservar
-- los campos y ajustes de SUNAT que pueda tener cada entorno.
DO $migration$
DECLARE
    definition TEXT;
    original_predicate TEXT := 'OR gen_texto_coincide(COALESCE(cl.razon_social, ''''), v_busqueda)';
    name_predicate TEXT := 'OR gen_texto_coincide(TRIM(CONCAT_WS('' '', cl.nombres, cl.apellido_paterno, cl.apellido_materno)), v_busqueda)';
    occurrences INTEGER;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO STRICT definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'ven_listar_comprobantes'
      AND p.pronargs = 11;

    occurrences := (length(definition) - length(replace(definition, name_predicate, '')))
                   / length(name_predicate);
    IF occurrences = 2 THEN
        RETURN; -- Ya aplicado: conteo y listado incluyen el nombre completo.
    END IF;
    IF occurrences <> 0 THEN
        RAISE EXCEPTION 'Búsqueda por nombre parcialmente instalada; revisar ven_listar_comprobantes';
    END IF;

    occurrences := (length(definition) - length(replace(definition, original_predicate, '')))
                   / length(original_predicate);
    IF occurrences <> 2 THEN
        RAISE EXCEPTION 'Definición inesperada de ven_listar_comprobantes: se esperaban conteo y listado';
    END IF;

    definition := replace(definition, original_predicate,
        original_predicate || chr(10) || '              ' || name_predicate);
    EXECUTE definition;
END;
$migration$;

COMMIT;
