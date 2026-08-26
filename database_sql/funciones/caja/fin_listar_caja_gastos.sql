DROP FUNCTION IF EXISTS fin_listar_caja_gastos(VARCHAR, INTEGER, INTEGER, DATE, DATE, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION fin_listar_caja_gastos(
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_categoria_gasto INTEGER DEFAULT NULL,
    p_id_sesion INTEGER DEFAULT NULL,
    p_estado INTEGER DEFAULT 1
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH filtrado AS (
        SELECT g.*
        FROM fin_caja_gasto g
        WHERE (p_estado IS NULL OR g.estado = p_estado)
          AND (p_fecha_desde IS NULL OR g.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR g.fecha <= p_fecha_hasta)
          AND (p_id_categoria_gasto IS NULL OR g.id_categoria_gasto = p_id_categoria_gasto)
          AND (p_id_sesion IS NULL OR g.id_sesion = p_id_sesion)
          AND (
              p_buscar = ''
              OR LOWER(COALESCE(g.concepto, '')) LIKE LOWER('%' || p_buscar || '%')
              OR LOWER(COALESCE(g.observacion, '')) LIKE LOWER('%' || p_buscar || '%')
              OR LOWER(COALESCE(g.numero_operacion, '')) LIKE LOWER('%' || p_buscar || '%')
          )
    )
    SELECT json_build_object(
        'total', (SELECT COUNT(*) FROM filtrado),
        'resumen', json_build_object(
            'total', (SELECT COALESCE(SUM(f.monto), 0) FROM filtrado f)
        ),
        'registros', COALESCE((
            SELECT json_agg(row_to_json(p) ORDER BY p.fecha DESC, p.id DESC)
            FROM (
                SELECT
                    f.id,
                    f.fecha,
                    f.concepto,
                    f.monto,
                    f.id_medio_pago AS "idMedioPago",
                    mp.nombre AS "medioPago",
                    f.id_categoria_gasto AS "idCategoriaGasto",
                    cat.nombre AS "categoriaGasto",
                    f.numero_operacion AS "numeroOperacion",
                    f.observacion,
                    f.id_sesion AS "idSesion",
                    f.estado
                FROM filtrado f
                LEFT JOIN gen_lista_opciones mp ON mp.id = f.id_medio_pago
                LEFT JOIN gen_lista_opciones cat ON cat.id = f.id_categoria_gasto
                ORDER BY f.fecha DESC, f.id DESC
                LIMIT p_limite
                OFFSET p_offset
            ) p
        ), '[]'::json)
    )
    INTO v_result;

    RETURN v_result;
END;
$function$;
