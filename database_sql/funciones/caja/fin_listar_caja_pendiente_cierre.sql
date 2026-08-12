-- Sesiones ABIERTA cuya fecha operativa es anterior a hoy (Lima).
-- Sirve para UI (banner de cierre pendiente) y job de notificaciones.

CREATE OR REPLACE FUNCTION fin_listar_caja_pendiente_cierre(
    p_id_sucursal INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha ASC, t.id ASC), '[]'::json)
    INTO v_registros
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.fecha_apertura AS "fechaApertura",
            ua.nombre AS "usuarioApertura",
            (CURRENT_DATE - s.fecha) AS "diasAbierta"
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        WHERE s.estado = 1
          AND UPPER(est.nombre) = 'ABIERTA'
          AND s.fecha < CURRENT_DATE
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', jsonb_array_length(v_registros::jsonb));
END;
$function$;
