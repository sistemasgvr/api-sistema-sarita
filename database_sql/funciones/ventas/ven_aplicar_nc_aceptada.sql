-- Aplica sobre el comprobante origen los efectos de custodia de una nota de crédito aceptada por SUNAT
DROP FUNCTION IF EXISTS public.ven_aplicar_nc_aceptada (p_id_nc integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.ven_aplicar_nc_aceptada (
  p_id_nc integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_id_origen INTEGER;
    v_total_nc NUMERIC(12,4);
    v_total_origen NUMERIC(12,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT c.id_comprobante_origen, c.total_importe
    INTO v_id_origen, v_total_nc
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    WHERE c.id = p_id_nc
      AND c.estado = 1
      AND tc.descripcion = '07';

    IF v_id_origen IS NULL THEN
        RETURN;
    END IF;

    SELECT total_importe INTO v_total_origen
    FROM ven_comprobante
    WHERE id = v_id_origen AND estado = 1;

    -- Misma regla que se aplicaba al crear la NC: devolución total, o NC
    -- que acredita líneas con cilindro.
    IF COALESCE(v_total_nc, 0) >= COALESCE(v_total_origen, 0) - 0.05
       OR EXISTS (
           SELECT 1
           FROM ven_comprobante_detalle d
           WHERE d.id_comprobante = p_id_nc
             AND d.estado = 1
             AND d.id_balon IS NOT NULL
       )
    THEN
        PERFORM ven_cerrar_custodia_comprobante(v_id_origen, p_id_usuario);
    END IF;
END;
$function$;
