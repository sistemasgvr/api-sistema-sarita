-- Obtiene caja sesion por id
DROP FUNCTION IF EXISTS public.fin_obtener_caja_sesion (p_id integer);

CREATE OR REPLACE FUNCTION public.fin_obtener_caja_sesion (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_totales JSON;
    v_fecha DATE;
    v_id_sucursal INT;
    v_fecha_cierre TIMESTAMP;
    v_totales_congelados JSON;
    v_totales_vivo JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_eventos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.fecha, s.id_sucursal, s.fecha_cierre, s.totales_cierre
    INTO v_fecha, v_id_sucursal, v_fecha_cierre, v_totales_congelados
    FROM fin_caja_sesion s WHERE s.id = p_id AND s.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Sesión no encontrada', 'registro', NULL);
    END IF;

    IF v_fecha_cierre IS NOT NULL AND v_totales_congelados IS NOT NULL THEN
        v_totales := v_totales_congelados;
    ELSE
        v_totales := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
    END IF;

    IF v_totales::JSONB->'porMedio' IS NULL THEN
        v_totales_vivo := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
        v_totales := (v_totales::JSONB || jsonb_build_object(
            'porMedio', v_totales_vivo->'porMedio',
            'efectivoNeto', v_totales_vivo->'efectivoNeto'
        ))::JSON;
    END IF;

    SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.id), '[]'::JSON) INTO v_gastos
    FROM (
        SELECT
            cg.id,
            cg.fecha,
            cg.concepto,
            cg.monto,
            cg.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cbg.alias, cbg.titular, cbg.numero_cuenta) AS "cuentaBancaria",
            cg.numero_operacion AS "numeroOperacion",
            cg.observacion
        FROM fin_caja_gasto cg
        LEFT JOIN gen_lista_opciones mp ON mp.id = cg.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cbg ON cbg.id = cg.id_cuenta_bancaria
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

    SELECT COALESCE(json_agg(row_to_json(ev) ORDER BY ev."fechaHora", ev.id), '[]'::JSON) INTO v_eventos
    FROM (
        SELECT
            e.id,
            e.tipo,
            e.monto,
            e.diferencia,
            e.observacion,
            e.id_usuario AS "idUsuario",
            u.nombre AS usuario,
            e.fecha_hora AS "fechaHora"
        FROM fin_caja_sesion_evento e
        LEFT JOIN auth_usuarios u ON u.id = e.id_usuario
        WHERE e.id_sesion = p_id
    ) ev;

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
            v_eventos AS eventos,
            COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0) AS "efectivoEsperado"
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
