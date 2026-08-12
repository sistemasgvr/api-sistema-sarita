CREATE OR REPLACE FUNCTION fin_listar_caja_sesiones(
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_sucursal INT DEFAULT NULL,
    p_estado_caja VARCHAR DEFAULT NULL,
    p_limite INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
      AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja));

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            ua.nombre AS "usuarioApertura",
            uc.nombre AS "usuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.estado = 1
          AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
          AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja))
        ORDER BY s.fecha DESC, s.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
