-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_eliminar_caja_gasto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.959Z
DROP FUNCTION IF EXISTS fin_eliminar_caja_gasto(p_id integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_eliminar_caja_gasto(p_id integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_sesion INT;
    v_estado VARCHAR;
    v_err TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT g.fecha, g.id_sesion
    INTO v_fecha, v_id_sesion
    FROM fin_caja_gasto g
    WHERE g.id = p_id AND g.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Gasto no encontrado', 'eliminado', false);
    END IF;

    IF v_id_sesion IS NOT NULL THEN
        SELECT UPPER(est.nombre) INTO v_estado
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id_sesion AND s.estado = 1;

        IF v_estado IS DISTINCT FROM 'ABIERTA' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede anular un gasto mientras la caja esté abierta. Si ya cerró, no se modifica el arqueo.',
                'eliminado',
                false
            );
        END IF;
    ELSE
        v_err := fin_caja_assert_abierta(v_fecha, NULL);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'eliminado', false);
        END IF;
    END IF;

    UPDATE fin_caja_gasto
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Gasto no encontrado', 'eliminado', false);
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
