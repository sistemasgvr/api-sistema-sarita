DROP FUNCTION IF EXISTS dash_garantias_alquiler();

CREATE OR REPLACE FUNCTION dash_garantias_alquiler()
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_activo INT;
    v_id_tipo_cobro     INT;
    v_total_en_caja     NUMERIC(14,2);
    v_contratos_activos INT;
    v_por_devolver      NUMERIC(14,2);
    v_ingresado_mes     NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT glo.id INTO v_id_estado_activo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoAlquiler' AND glo.nombre = 'ACTIVO'
    LIMIT 1;

    SELECT glo.id INTO v_id_tipo_cobro
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoMovimientoGarantia' AND glo.nombre = 'COBRO'
    LIMIT 1;

    -- Total de garantías de alquiler con saldo pendiente de devolución.
    SELECT COALESCE(SUM(g.monto_saldo), 0)
    INTO v_total_en_caja
    FROM ven_garantia g
    WHERE g.estado = 1
      AND g.id_alquiler IS NOT NULL
      AND g.monto_saldo > 0;

    -- Contratos de alquiler vigentes.
    SELECT COUNT(*)
    INTO v_contratos_activos
    FROM bal_alquiler al
    WHERE al.estado = 1
      AND (v_id_estado_activo IS NULL OR al.id_estado = v_id_estado_activo);

    -- Garantías con saldo pendiente cuyo alquiler ya finalizó (hay que devolverlas).
    SELECT COALESCE(SUM(g.monto_saldo), 0)
    INTO v_por_devolver
    FROM ven_garantia g
    JOIN bal_alquiler al ON al.id = g.id_alquiler
    WHERE g.estado = 1
      AND g.monto_saldo > 0
      AND (al.fecha_fin_real IS NOT NULL OR al.fecha_fin_pactada < CURRENT_DATE);

    -- Monto cobrado (ingresado) este mes por garantías de alquiler.
    SELECT COALESCE(SUM(gm.monto), 0)
    INTO v_ingresado_mes
    FROM ven_garantia_movimiento gm
    JOIN ven_garantia g ON g.id = gm.id_garantia
    WHERE gm.estado = 1
      AND g.id_alquiler IS NOT NULL
      AND (v_id_tipo_cobro IS NULL OR gm.id_tipo_movimiento = v_id_tipo_cobro)
      AND DATE_TRUNC('month', gm.fecha) = DATE_TRUNC('month', CURRENT_DATE);

    RETURN json_build_object(
        'totalEnCaja', v_total_en_caja,
        'contratosActivos', v_contratos_activos,
        'porDevolverClientes', v_por_devolver,
        'ingresadoEsteMes', v_ingresado_mes
    );
END;
$$;
