-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_obtener_caja_sesion
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_obtener_caja_sesion(p_id integer);

CREATE OR REPLACE FUNCTION fin_obtener_caja_sesion(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_totales JSON;
    v_fecha DATE;
    v_id_sucursal INT;
    v_gastos JSON;
    v_depositos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.fecha, s.id_sucursal INTO v_fecha, v_id_sucursal
    FROM fin_caja_sesion s WHERE s.id = p_id AND s.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Sesión no encontrada', 'registro', NULL);
    END IF;

    v_totales := fin_caja_calcular_totales(v_fecha, v_id_sucursal);

    SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.id), '[]'::JSON) INTO v_gastos
    FROM (
        SELECT
            cg.id,
            cg.fecha,
            cg.concepto,
            cg.monto,
            cg.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cg.numero_operacion AS "numeroOperacion",
            cg.observacion
        FROM fin_caja_gasto cg
        LEFT JOIN gen_lista_opciones mp ON mp.id = cg.id_medio_pago
        WHERE cg.estado = 1 AND cg.id_sesion = p_id
    ) g;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON) INTO v_depositos
    FROM (
        SELECT
            cd.id,
            cd.fecha,
            cd.monto,
            cd.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            cd.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cd.numero_operacion AS "numeroOperacion",
            cd.observacion
        FROM fin_caja_deposito cd
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cd.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = cd.id_medio_pago
        WHERE cd.estado = 1 AND cd.id_sesion = p_id
    ) d;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            ua.nombre AS "usuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            uc.nombre AS "usuarioCierre",
            v_totales AS totales,
            v_gastos AS gastos,
            v_depositos AS depositos,
            (
                COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
                + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
                + COALESCE((v_totales->>'garantiasCobroMediosCaja')::NUMERIC, 0)
                - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
                - COALESCE((v_totales->>'gastosCaja')::NUMERIC, 0)
                - COALESCE((v_totales->>'garantiasDevolucionMediosCaja')::NUMERIC, 0)
            ) AS "cajaEsperada"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
