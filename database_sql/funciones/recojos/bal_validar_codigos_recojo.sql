-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_validar_codigos_recojo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.609Z
DROP FUNCTION IF EXISTS bal_validar_codigos_recojo(p_id_recojo integer, p_codigos json);

CREATE OR REPLACE FUNCTION bal_validar_codigos_recojo(p_id_recojo integer, p_codigos json DEFAULT '[]'::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_codigos TEXT[];
    v_esperados JSONB := '[]'::JSONB;
    v_coinciden JSONB := '[]'::JSONB;
    v_faltantes JSONB := '[]'::JSONB;
    v_no_pertenecen JSONB := '[]'::JSONB;
    v_rec RECORD;
    v_codigo TEXT;
    v_encontrado BOOLEAN;
    v_idx INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre
    INTO v_estado
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id_recojo AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se pueden validar códigos en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    -- Detalles esperados (con el código de cilindro vinculado).
    FOR v_rec IN
        SELECT
            rd.id AS id_recojo_detalle,
            rd.id_prestamo_detalle,
            rd.id_alquiler_detalle,
            COALESCE(pd.id_balon, ad.id_balon) AS id_balon,
            b.codigo_balon
        FROM bal_recojo_detalle rd
        LEFT JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
        LEFT JOIN bal_alquiler_detalle ad ON ad.id = rd.id_alquiler_detalle AND ad.estado = 1
        LEFT JOIN bal_balon b ON b.id = COALESCE(pd.id_balon, ad.id_balon) AND b.estado = 1
        WHERE rd.id_recojo = p_id_recojo AND rd.estado = 1
    LOOP
        v_esperados := v_esperados || jsonb_build_object(
            'idRecojoDetalle', v_rec.id_recojo_detalle,
            'idPrestamoDetalle', v_rec.id_prestamo_detalle,
            'idAlquilerDetalle', v_rec.id_alquiler_detalle,
            'idBalon', v_rec.id_balon,
            'codigo', v_rec.codigo_balon
        );
    END LOOP;

    -- Normaliza los códigos escaneados a un array de texto.
    SELECT COALESCE(
        ARRAY_AGG(NULLIF(TRIM(VALUE::TEXT), '"')),
        ARRAY[]::TEXT[]
    )
    INTO v_codigos
    FROM json_array_elements_text(COALESCE(p_codigos::JSON, '[]'::JSON));

    -- Marca los detalles cuyo código fue escaneado.
    v_idx := 0;
    WHILE v_idx < jsonb_array_length(v_esperados)
    LOOP
        v_rec := NULL;
        SELECT
            (v_esperados -> v_idx ->> 'idRecojoDetalle')::INTEGER AS id_recojo_detalle,
            (v_esperados -> v_idx ->> 'idPrestamoDetalle')::INTEGER AS id_prestamo_detalle,
            (v_esperados -> v_idx ->> 'idAlquilerDetalle')::INTEGER AS id_alquiler_detalle,
            (v_esperados -> v_idx ->> 'idBalon')::INTEGER AS id_balon,
            v_esperados -> v_idx ->> 'codigo' AS codigo
        INTO v_rec;

        v_encontrado := FALSE;
        IF v_rec.codigo IS NOT NULL THEN
            SELECT TRUE INTO v_encontrado
            FROM unnest(v_codigos) c
            WHERE UPPER(c) = UPPER(v_rec.codigo);
        END IF;

        IF v_encontrado THEN
            v_coinciden := v_coinciden || (v_esperados -> v_idx);
        ELSE
            v_faltantes := v_faltantes || (v_esperados -> v_idx);
        END IF;

        v_idx := v_idx + 1;
    END LOOP;

    -- Códigos escaneados que no corresponden a ningún detalle del recojo.
    SELECT COALESCE(
        jsonb_agg(DISTINCT to_jsonb(c)),
        '[]'::JSONB
    )
    INTO v_no_pertenecen
    FROM unnest(v_codigos) c
    WHERE NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_esperados) e
        WHERE e ->> 'codigo' IS NOT NULL
          AND UPPER(e ->> 'codigo') = UPPER(c)
    );

    RETURN json_build_object(
        'ok', TRUE,
        'total', jsonb_array_length(v_esperados),
        'coinciden', v_coinciden,
        'faltantes', v_faltantes,
        'no_pertenecen', v_no_pertenecen,
        'completo', jsonb_array_length(v_faltantes) = 0
    );
END;
$function$
