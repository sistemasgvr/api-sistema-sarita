-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_revertir_efectos_comprobante
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.820Z
DROP FUNCTION IF EXISTS ven_revertir_efectos_comprobante(p_id integer, p_id_usuario_auditoria integer, p_exigir_sin_pagos boolean);

CREATE OR REPLACE FUNCTION ven_revertir_efectos_comprobante(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_exigir_sin_pagos boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_hay_pagos BOOLEAN;
    v_codigo_tipo VARCHAR;
    v_nombre_tipo_venta VARCHAR;
    v_codigo_tipo_documento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id, NULL);

    IF p_exigir_sin_pagos AND v_hay_pagos THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', 'No se puede eliminar: la cuenta por cobrar tiene pagos. Anule primero los pagos en Finanzas.'
        );
    END IF;

    -- Resolver el código del tipo de documento para inv_revertir_por_documento
    SELECT
        tc.descripcion,
        COALESCE(tv.nombre, 'VENTA')
    INTO v_codigo_tipo, v_nombre_tipo_venta
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
    WHERE c.id = p_id AND c.estado = 1;

    v_codigo_tipo_documento := ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta);

    -- Revertir kardex unificado (producto + balón) vía inv_movimiento
    PERFORM inv_revertir_por_documento(
        v_codigo_tipo_documento,
        p_id,
        p_id_usuario_auditoria
    );

    IF NOT v_hay_pagos THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id, NULL);
    END IF;

    BEGIN
        PERFORM ven_cerrar_custodia_comprobante(p_id, p_id_usuario_auditoria);
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('ok', FALSE, 'error', SQLERRM);
    END;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$
