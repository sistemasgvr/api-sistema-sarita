CREATE OR REPLACE FUNCTION fin_eliminar_caja_deposito(
    p_id INT,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_sesion INT;
    v_estado VARCHAR;
    v_err TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.fecha, d.id_sesion
    INTO v_fecha, v_id_sesion
    FROM fin_caja_deposito d
    WHERE d.id = p_id AND d.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Depósito no encontrado', 'eliminado', false);
    END IF;

    IF v_id_sesion IS NOT NULL THEN
        SELECT UPPER(est.nombre) INTO v_estado
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id_sesion AND s.estado = 1;

        IF v_estado IS DISTINCT FROM 'ABIERTA' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede anular un depósito mientras la caja esté abierta. Si ya cerró, no se modifica el arqueo.',
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

    UPDATE fin_caja_deposito
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Depósito no encontrado', 'eliminado', false);
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
