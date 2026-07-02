CREATE OR REPLACE FUNCTION pro_actualizar_stock(
    p_id INTEGER,
    p_stock NUMERIC DEFAULT NULL,
    p_stock_minimo NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_stock IS NOT NULL AND p_stock < 0 THEN
        RETURN json_build_object('error', 'El stock no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_stock_minimo IS NOT NULL AND p_stock_minimo < 0 THEN
        RETURN json_build_object('error', 'El stock mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    UPDATE pro_stock
    SET
        stock = COALESCE(p_stock, stock),
        stock_minimo = COALESCE(p_stock_minimo, stock_minimo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_stock(p_id);
END;
$function$;
