-- Baja lógica de una cuenta financiera. Reglas:
--   * No se puede eliminar si tiene pagos activos aplicados (en la propia
--     cuenta o en cualquiera de sus cuotas hijas si es cabecera de plan).
--   * Si es cabecera de plan, se dan de baja también las cuotas hijas.
--   * No se pueden eliminar cuotas individuales directamente (elimina el plan).

DROP FUNCTION IF EXISTS fin_eliminar_cuenta(INT, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_eliminar_cuenta(
    p_id         INT,
    p_tipo       VARCHAR DEFAULT NULL,
    p_id_usuario INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta   fin_cuenta%ROWTYPE;
    v_id_tipo  INT;
    v_hay_pagos BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error', 'La cuenta no existe o ya está inactiva');
    END IF;

    -- No permitir eliminar cuotas individuales
    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error',
            'No se puede eliminar una cuota individual: elimina el plan completo desde su cabecera');
    END IF;

    -- Validación opcional del tipo
    IF p_tipo IS NOT NULL THEN
        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = UPPER(p_tipo)
        LIMIT 1;
        IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
            RETURN json_build_object('eliminado', false, 'id', p_id, 'error', 'La cuenta no corresponde al tipo indicado');
        END IF;
    END IF;

    -- Verificar pagos activos (en la propia cuenta o en cualquier cuota hija)
    SELECT EXISTS(
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND (c.id = p_id OR c.id_cuenta_padre = p_id)
    ) INTO v_hay_pagos;

    IF v_hay_pagos THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error',
            'No se puede eliminar: hay pagos aplicados. Anula primero los pagos activos.');
    END IF;

    -- Baja lógica de la cabecera + cuotas hijas
    UPDATE fin_cuenta
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id OR id_cuenta_padre = p_id;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$$;
