-- Calcula el siguiente número de comprobante para un tipo y serie
DROP FUNCTION IF EXISTS public.ven_obtener_siguiente_numero (
  p_id_tipo_comprobante integer,
  p_serie character varying
);

CREATE OR REPLACE FUNCTION public.ven_obtener_siguiente_numero (
  p_id_tipo_comprobante integer,
  p_serie character varying
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_serie VARCHAR;
    v_ultimo BIGINT;
    v_siguiente VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'numero', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'numero', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'numero', NULL);
    END IF;

    PERFORM pg_advisory_xact_lock(872015, hashtext(v_serie));

    SELECT COALESCE(MAX(numero::BIGINT), 0) INTO v_ultimo
    FROM (
        SELECT serie, numero FROM ven_comprobante
        UNION ALL
        SELECT serie, numero FROM ven_comprobante_historial_cpe
    ) referencias
    WHERE UPPER(TRIM(serie)) = v_serie AND numero ~ '^[0-9]+$';

    IF v_serie IN ('FC02','BC02') AND to_regclass('public.ven_cpe_correccion_nota') IS NOT NULL THEN
        SELECT GREATEST(v_ultimo,COALESCE(MAX(numero),0)) INTO v_ultimo
        FROM ven_cpe_correccion_nota WHERE serie=v_serie;
    END IF;
    IF v_serie IN ('F002','B002') AND to_regclass('public.ven_cpe_correccion_reserva') IS NOT NULL THEN
        SELECT GREATEST(v_ultimo,COALESCE(MAX(numero),0)) INTO v_ultimo
        FROM ven_cpe_correccion_reserva WHERE serie=v_serie;
    END IF;
    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 8, '0');

    RETURN json_build_object(
        'serie', v_serie,
        'id_tipo_comprobante', p_id_tipo_comprobante,
        'ultimo_numero', CASE WHEN v_ultimo = 0 THEN NULL ELSE LPAD(v_ultimo::TEXT, 8, '0') END,
        'numero', v_siguiente
    );
END;
$function$;
