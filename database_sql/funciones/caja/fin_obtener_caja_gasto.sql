-- Function: fin_obtener_caja_gasto
-- Faltaba: caja.model.ts la llamaba desde GET /caja/gastos/:id pero nunca se
-- creó, así que el endpoint fallaba con "function does not exist". Creada en
-- Fase 3 al añadir la cuenta bancaria al gasto.

DROP FUNCTION IF EXISTS fin_obtener_caja_gasto(p_id integer);

CREATE OR REPLACE FUNCTION fin_obtener_caja_gasto(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.fecha,
            g.concepto,
            g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            g.id_categoria_gasto AS "idCategoriaGasto",
            cat.nombre AS "categoriaGasto",
            g.numero_operacion AS "numeroOperacion",
            g.observacion,
            g.id_sesion AS "idSesion",
            s.id_sucursal AS "idSucursal",
            g.estado,
            g.fecha_creacion AS "fechaCreacion",
            g.id_usuario_creacion AS "idUsuarioCreacion",
            uc.nombre AS "usuarioCreacion"
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones cat ON cat.id = g.id_categoria_gasto
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion
        LEFT JOIN auth_usuarios uc ON uc.id = g.id_usuario_creacion
        WHERE g.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
