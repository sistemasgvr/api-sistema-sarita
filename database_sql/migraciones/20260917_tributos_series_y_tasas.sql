-- Percepciones y retenciones: la serie y la tasa dejan de estar en el código.
--
-- 1. Funciones ven_listar_series_percepcion / com_listar_series_retencion: las
--    series ya usadas por empresa con su último y siguiente correlativo, para
--    que el formulario ofrezca un select en lugar de una serie fija (P001/R001).
--    Mismo contrato y criterio que doc_listar_series_gre.
-- 2. Listas TasaPercepcion / TasaRetencion: el porcentaje sale del nombre del
--    régimen y pasa a ser un catálogo propio asociado al régimen por su código,
--    de modo que un régimen pueda tener más de una tasa y se cambie sin desplegar.
--
-- Idempotente: se puede volver a aplicar sin efectos.
BEGIN;

-- >>> funciones/percepciones/ven_listar_series_percepcion.sql
DROP FUNCTION IF EXISTS ven_listar_series_percepcion(p_id_empresa integer);

CREATE OR REPLACE FUNCTION ven_listar_series_percepcion(p_id_empresa integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH usadas AS (
        SELECT
            UPPER(TRIM(p.serie)) AS serie,
            MAX(CASE WHEN p.numero ~ '^[0-9]+$' THEN p.numero::BIGINT END) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM ven_percepcion p
        WHERE p.serie IS NOT NULL
          AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
        GROUP BY UPPER(TRIM(p.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE 'P%'
        UNION ALL
        SELECT 'P001', NULL::BIGINT, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = 'P001')
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;

-- >>> funciones/retenciones/com_listar_series_retencion.sql
DROP FUNCTION IF EXISTS com_listar_series_retencion(p_id_empresa integer);

CREATE OR REPLACE FUNCTION com_listar_series_retencion(p_id_empresa integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH usadas AS (
        SELECT
            UPPER(TRIM(r.serie)) AS serie,
            MAX(CASE WHEN r.numero ~ '^[0-9]+$' THEN r.numero::BIGINT END) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM com_retencion r
        WHERE r.serie IS NOT NULL
          AND (p_id_empresa IS NULL OR r.id_empresa = p_id_empresa)
        GROUP BY UPPER(TRIM(r.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE 'R%'
        UNION ALL
        SELECT 'R001', NULL::BIGINT, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = 'R001')
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;

-- >>> seeds/percepciones_retenciones_lista_opciones.sql (tasas y nombres de régimen)

-- El nombre del régimen ya no lleva el porcentaje: la tasa es un dato aparte.
UPDATE gen_lista_opciones o
SET nombre = v.nombre, fecha_modificacion = now()
FROM gen_lista l, (VALUES
    ('RegimenPercepcion', '01', 'Percepción venta interna'),
    ('RegimenPercepcion', '02', 'Percepción a la adquisición de combustible'),
    ('RegimenPercepcion', '03', 'Percepción realizada al agente de percepción con tasa especial'),
    ('RegimenRetencion', '01', 'Régimen general'),
    ('RegimenRetencion', '02', 'Régimen con tasa especial')
) AS v(lista, codigo, nombre)
WHERE l.id = o.id_lista AND l.nombre = v.lista AND TRIM(o.descripcion) = v.codigo
  AND o.nombre IS DISTINCT FROM v.nombre;

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TasaPercepcion', 'Tasas de percepción por régimen (código del régimen en descripcion)'),
        ('TasaRetencion', 'Tasas de retención por régimen (código del régimen en descripcion)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.tasa, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', '2%'),
    ('02', '1%'),
    ('03', '0.5%')
) AS v(codigo, tasa)
WHERE l.nombre = 'TasaPercepcion'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.descripcion = v.codigo AND o.nombre = v.tasa
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.tasa, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', '3%'),
    ('02', '6%')
) AS v(codigo, tasa)
WHERE l.nombre = 'TasaRetencion'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.descripcion = v.codigo AND o.nombre = v.tasa
  );

COMMIT;
