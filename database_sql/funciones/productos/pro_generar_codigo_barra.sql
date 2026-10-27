-- Genera el siguiente código de barras interno EAN-13 de un producto
DROP FUNCTION IF EXISTS public.pro_generar_codigo_barra (p_id_producto integer);

CREATE OR REPLACE FUNCTION public.pro_generar_codigo_barra (p_id_producto integer DEFAULT NULL::integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_actual VARCHAR(50);
    v_siguiente BIGINT;
    v_base VARCHAR(12);
    v_suma INTEGER := 0;
    v_codigo VARCHAR(13);
    i INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto IS NOT NULL THEN
        SELECT NULLIF(TRIM(codigo_barra), '')
        INTO v_actual
        FROM pro_producto
        WHERE id = p_id_producto AND estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object(
                'error', 'Producto ' || p_id_producto || ' no encontrado'
            );
        END IF;

        IF v_actual IS NOT NULL THEN
            RETURN json_build_object(
                'registro', json_build_object('codigo_barra', v_actual)
            );
        END IF;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('pro_generar_codigo_barra'));

    SELECT COALESCE(MAX(SUBSTRING(TRIM(codigo_barra) FROM 3 FOR 10)::BIGINT), 0) + 1
    INTO v_siguiente
    FROM pro_producto
    WHERE TRIM(codigo_barra) ~ '^20[0-9]{11}$';

    IF v_siguiente > 9999999999 THEN
        RETURN json_build_object('error', 'Se agotó el rango de códigos de barras internos');
    END IF;

    v_base := '20' || LPAD(v_siguiente::TEXT, 10, '0');

    FOR i IN 1..12 LOOP
        v_suma := v_suma + SUBSTRING(v_base FROM i FOR 1)::INTEGER * CASE WHEN i % 2 = 0 THEN 3 ELSE 1 END;
    END LOOP;
    v_codigo := v_base || ((10 - v_suma % 10) % 10)::TEXT;

    IF p_id_producto IS NOT NULL THEN
        UPDATE pro_producto
        SET
            codigo_barra = v_codigo,
            fecha_modificacion = NOW()
        WHERE id = p_id_producto;
    END IF;

    RETURN json_build_object(
        'registro', json_build_object('codigo_barra', v_codigo)
    );
END;
$function$;
