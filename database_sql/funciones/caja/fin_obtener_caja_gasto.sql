DROP FUNCTION IF EXISTS fin_obtener_caja_gasto(INT);

CREATE OR REPLACE FUNCTION fin_obtener_caja_gasto(
    p_id INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id, g.fecha, g.concepto, g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_categoria_gasto AS "idCategoriaGasto",
            cat.nombre AS "categoriaGasto",
            g.numero_operacion AS "numeroOperacion",
            g.observacion,
            g.id_sesion AS "idSesion",
            g.estado
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones cat ON cat.id = g.id_categoria_gasto
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Gasto no encontrado', 'registro', NULL);
    END IF;

    RETURN json_build_object('error', NULL, 'registro', v_registro);
END;
$function$;
