CREATE OR REPLACE FUNCTION pro_generar_codigo_producto(
    p_prefijo VARCHAR DEFAULT 'PRO'
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_prefijo VARCHAR(10);
    v_siguiente INTEGER;
    v_codigo VARCHAR(30);
BEGIN
    SET TIME ZONE 'America/Lima';

    v_prefijo := UPPER(TRIM(COALESCE(NULLIF(TRIM(p_prefijo), ''), 'PRO')));
    v_prefijo := regexp_replace(v_prefijo, '[^A-Z0-9]', '', 'g');

    IF v_prefijo IS NULL OR LENGTH(v_prefijo) < 2 THEN
        v_prefijo := 'PRO';
    ELSIF LENGTH(v_prefijo) > 10 THEN
        v_prefijo := LEFT(v_prefijo, 10);
    END IF;

    SELECT COALESCE(
        MAX(
            CASE
                WHEN UPPER(TRIM(codigo)) ~ ('^' || v_prefijo || '-[0-9]+$')
                    THEN NULLIF(regexp_replace(UPPER(TRIM(codigo)), '^.*-', ''), '')::INTEGER
                ELSE NULL
            END
        ),
        0
    ) + 1
    INTO v_siguiente
    FROM pro_producto;

    v_codigo := v_prefijo || '-' || LPAD(v_siguiente::TEXT, GREATEST(3, LENGTH(v_siguiente::TEXT)), '0');

    IF EXISTS (
        SELECT 1
        FROM pro_producto
        WHERE LOWER(TRIM(codigo)) = LOWER(v_codigo)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un producto con el código ' || v_codigo,
            'registro', NULL
        );
    END IF;

    RETURN json_build_object(
        'registro', json_build_object('codigo', v_codigo)
    );
END;
$function$;
