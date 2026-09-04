-- Function: gen_eliminar_cuenta_bancaria
-- Fase 3: una cuenta de la empresa que ya recibió dinero no se puede dar de
-- baja; dejaría cobros, pagos, depósitos o gastos apuntando a una cuenta
-- inactiva y los resúmenes de caja no cuadrarían con el banco.

DROP FUNCTION IF EXISTS gen_eliminar_cuenta_bancaria(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_eliminar_cuenta_bancaria(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ambito VARCHAR;
    v_usos INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ambito INTO v_ambito FROM gen_cuenta_bancaria WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_ambito = 'EMPRESA' THEN
        SELECT
            (SELECT COUNT(*) FROM fin_pago WHERE id_cuenta_bancaria = p_id AND estado = 1)
          + (SELECT COUNT(*) FROM fin_caja_deposito WHERE id_cuenta_bancaria = p_id AND estado = 1)
          + (SELECT COUNT(*) FROM fin_caja_gasto WHERE id_cuenta_bancaria = p_id AND estado = 1)
          + (SELECT COUNT(*) FROM ven_comprobante_pago WHERE id_cuenta_bancaria = p_id AND estado = 1)
          + (SELECT COUNT(*) FROM ven_garantia_movimiento WHERE id_cuenta_bancaria = p_id AND estado = 1)
          + (SELECT COUNT(*) FROM ven_garantia
             WHERE (id_cuenta_bancaria = p_id OR id_cuenta_bancaria_reembolso = p_id) AND estado = 1)
          + (SELECT COUNT(*) FROM fin_garantia
             WHERE (id_cuenta_bancaria = p_id OR id_cuenta_bancaria_reembolso = p_id) AND estado = 1)
        INTO v_usos;

        IF v_usos > 0 THEN
            RETURN json_build_object(
                'error', format(
                    'La cuenta tiene %s movimiento(s) de dinero registrados y no se puede eliminar. Quítale los medios de pago asociados para dejar de ofrecerla en los cobros.',
                    v_usos
                ),
                'eliminado', FALSE,
                'id', p_id
            );
        END IF;
    END IF;

    UPDATE gen_cuenta_medio_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_cuenta_bancaria = p_id AND estado = 1;

    UPDATE gen_cuenta_bancaria
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
