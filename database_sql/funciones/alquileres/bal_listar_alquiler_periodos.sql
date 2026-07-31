CREATE OR REPLACE FUNCTION bal_listar_alquiler_periodos(
    p_id_alquiler INTEGER,
    p_limite INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'id_alquiler es obligatorio', 'registros', '[]'::JSON, 'total', 0);
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM bal_alquiler_periodo p
    WHERE p.id_alquiler = p_id_alquiler AND p.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.id_alquiler,
            p.numero_periodo,
            p.fecha_inicio,
            p.fecha_fin,
            p.monto,
            p.id_producto,
            pr.codigo AS codigo_producto,
            pr.nombre AS nombre_producto,
            p.id_comprobante,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante,
            p.id_estado,
            ea.nombre AS nombre_estado,
            p.observacion,
            p.fecha_creacion
        FROM bal_alquiler_periodo p
        LEFT JOIN pro_producto pr ON p.id_producto = pr.id
        LEFT JOIN ven_comprobante cv ON p.id_comprobante = cv.id
        LEFT JOIN gen_lista_opciones ea ON p.id_estado = ea.id
        WHERE p.id_alquiler = p_id_alquiler AND p.estado = 1
        ORDER BY p.numero_periodo DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
