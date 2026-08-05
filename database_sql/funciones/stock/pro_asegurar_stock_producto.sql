CREATE OR REPLACE FUNCTION pro_asegurar_stock_producto(
    p_id_producto INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto IS NULL THEN
        RETURN;
    END IF;

    -- Solo accesorios con afecta_stock (nunca gases ni servicios).
    IF NOT EXISTS (
        SELECT 1
        FROM pro_producto p
        WHERE p.id = p_id_producto
          AND p.estado = 1
          AND COALESCE(p.afecta_stock, FALSE) = TRUE
          AND COALESCE(p.es_gas, FALSE) = FALSE
          AND COALESCE(p.es_servicio, FALSE) = FALSE
    ) THEN
        RETURN;
    END IF;

    -- Reactivar filas inactivas (UNIQUE id_almacen + id_producto).
    UPDATE pro_stock s
    SET
        estado = 1,
        stock = CASE WHEN s.estado = 0 THEN 0 ELSE s.stock END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM gen_almacen a
    WHERE s.id_almacen = a.id
      AND s.id_producto = p_id_producto
      AND a.estado = 1
      AND s.estado = 0;

    INSERT INTO pro_stock (
        id_almacen,
        id_producto,
        stock,
        stock_minimo,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    SELECT
        a.id,
        p_id_producto,
        0,
        0,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM gen_almacen a
    WHERE a.estado = 1
      AND NOT EXISTS (
          SELECT 1
          FROM pro_stock s
          WHERE s.id_almacen = a.id
            AND s.id_producto = p_id_producto
      );
END;
$function$;
