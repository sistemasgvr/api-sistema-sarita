CREATE OR REPLACE FUNCTION pro_generar_codigo_ubicacion(
    p_prefijo VARCHAR DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_prefijo VARCHAR(17);
    v_siguiente INTEGER;
    v_codigo VARCHAR(20);
    v_actualizado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_prefijo := UPPER(TRIM(COALESCE(p_prefijo, '')));
    v_prefijo := regexp_replace(v_prefijo, '[^A-Z0-9\-]', '', 'g');
    v_prefijo := regexp_replace(v_prefijo, '-+', '-', 'g');
    v_prefijo := TRIM(BOTH '-' FROM v_prefijo);

    IF v_prefijo IS NULL OR LENGTH(v_prefijo) < 2 THEN
        -- Compatibilidad: secuencia numérica si no hay prefijo
        SELECT COALESCE(MAX(codigo_ubicacion::INTEGER), 0) + 1
        INTO v_siguiente
        FROM pro_producto
        WHERE codigo_ubicacion ~ '^\d+$';

        v_codigo := LPAD(v_siguiente::TEXT, GREATEST(4, LENGTH(v_siguiente::TEXT)), '0');
    ELSE
        IF LENGTH(v_prefijo) > 17 THEN
            v_prefijo := LEFT(v_prefijo, 17);
        END IF;

        SELECT COALESCE(
            MAX(
                CASE
                    WHEN codigo_ubicacion ~ ('^' || v_prefijo || '-[0-9]+$')
                        THEN NULLIF(regexp_replace(codigo_ubicacion, '^.*-', ''), '')::INTEGER
                    ELSE NULL
                END
            ),
            0
        ) + 1
        INTO v_siguiente
        FROM pro_producto;

        v_codigo := v_prefijo || '-' || LPAD(v_siguiente::TEXT, 2, '0');

        IF LENGTH(v_codigo) > 20 THEN
            RETURN json_build_object(
                'error', 'El código de ubicación generado supera el máximo permitido'
            );
        END IF;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pro_producto
        WHERE LOWER(TRIM(codigo_ubicacion)) = LOWER(v_codigo)
          AND (p_id_producto IS NULL OR id <> p_id_producto)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un producto con el código de ubicación ' || v_codigo
        );
    END IF;

    IF p_id_producto IS NOT NULL THEN
        UPDATE pro_producto
        SET
            codigo_ubicacion = v_codigo,
            fecha_modificacion = NOW()
        WHERE id = p_id_producto;

        GET DIAGNOSTICS v_actualizado = ROW_COUNT;

        IF v_actualizado = 0 THEN
            RETURN json_build_object(
                'error', 'Producto ' || p_id_producto || ' no encontrado'
            );
        END IF;
    END IF;

    RETURN json_build_object(
        'registro', json_build_object('codigo_ubicacion', v_codigo)
    );
END;
$function$;
