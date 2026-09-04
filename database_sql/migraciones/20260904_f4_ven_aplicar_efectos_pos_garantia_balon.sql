-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
-- Aplicar DESPUÉS de:
--   20260904_f4_prestamo_garantia_balon_esquema.sql (columna bal_prestamo_detalle.rol,
--     catálogos PropietarioBalon.GARANTIA_CLIENTE y TipoMovBalon.ENTRADA_GARANTIA)
--   20260904_f4_prestamo_detalle_rol_y_fix.sql (bal_crear_prestamo_detalle acepta p_rol)
--
-- Fase 4 (apunte 1.c.viii) — préstamo con garantía de balón. Extiende el bloque
-- 'prestamos' de ven_aplicar_efectos_pos con un sub-objeto opcional garantiaBalon
-- por ítem: { codigoBalon (requerido), numeroSerie?, idTipoBalon?, idProductoGas?,
-- fechaUltimaPruebaHidrostatica?, vigenciaPruebaHidrostaticaAnios? (default 5),
-- observacion? }. Cuando viene, además de lo que el bloque ya hacía (préstamo +
-- detalle ENTREGADO + garantía monetaria opcional):
--   1. Registra el cilindro del cliente vía bal_crear_balon (propietario
--      GARANTIA_CLIENTE, catálogo nuevo) — si su próxima prueba hidrostática ya
--      venció, lo anota en observacion.
--   2. Registra la entrada física a custodia de Sarita vía inv_registrar_movimiento
--      (BALON / ENTRADA_GARANTIA, catálogo nuevo).
--   3. Enlaza ese balón al mismo préstamo con bal_crear_prestamo_detalle(..., p_rol
--      => 'GARANTIA') — junto al detalle ENTREGADO que el bloque ya creaba.

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_aplicar_efectos_pos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_arr JSON;
    v_result JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_baja INTEGER;
    v_garantia JSON;
    v_periodo JSON;
    v_id_producto INTEGER;
    v_id_prestamo_detalle INTEGER;
    v_arr_detalles JSONB := '[]'::JSONB;
    v_garantia_balon JSON;
    v_id_balon_garantia INTEGER;
    v_id_propietario_garantia INTEGER;
    v_vigencia_ph_garantia INTEGER;
    v_fecha_ultima_ph_garantia DATE;
    v_fecha_proxima_ph_garantia DATE;
    v_observacion_balon_garantia VARCHAR;
    v_mov_garantia JSON;
    v_id_estado_balon_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL OR p_efectos IS NULL OR p_efectos::TEXT IN ('null', '{}', '[]') THEN
        RETURN;
    END IF;

    SELECT id_cliente, serie, numero
    INTO v_id_cliente, v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_comprobante AND estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante no existe o está inactivo';
    END IF;

    -- Recargas mostrador
    v_arr := CASE WHEN json_typeof(p_efectos->'recargas') = 'array' THEN p_efectos->'recargas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_vincular_recarga_cliente_comprobante(
            p_id_comprobante,
            v_id_cliente,
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULLIF(v_item->>'capacidad', '')::NUMERIC,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'idBalonOrigen', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Préstamos de cilindro (+ garantía opcional)
    v_arr := CASE WHEN json_typeof(p_efectos->'prestamos') = 'array' THEN p_efectos->'prestamos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_prestamo(
            NULLIF(v_item->>'idTipoPrestamo', '')::INTEGER,
            NULL,
            v_id_cliente,
            NULL,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(v_item->>'fechaSalida', '')::DATE,
            NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'titulo', '')), ''),
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'idEstado', '')::INTEGER,
            p_id_comprobante,
            NULL,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
        IF v_id_prestamo IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el préstamo POS';
        END IF;

        v_result := bal_crear_prestamo_detalle(
            v_id_prestamo,
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULL,
            NULLIF(COALESCE(v_item->>'fechaEntregado', v_item->>'fechaSalida'), '')::DATE,
            NULLIF(COALESCE(v_item->>'fechaPrestamo', v_item->>'fechaSalida'), '')::DATE,
            30,
            NULLIF(COALESCE(v_item->>'fechaVencimiento', v_item->>'fechaRetornoPactada'), '')::DATE,
            NULL, NULL, NULL, NULL, NULL,
            NULLIF(v_item->>'idEstadoDetalle', '')::INTEGER,
            NULLIF(TRIM(COALESCE(v_item->>'observacionDetalle', '')), ''),
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_prestamo_detalle := (v_result->'registro'->>'id')::INTEGER;

        -- Auto-recojo: el préstamo ya tiene fecha de retorno pactada, por lo que se
        -- programa el recojo sin pasar por la pantalla de programación manual.
        -- El cilindro se queda PRESTADO_CLIENTE hasta que el chófer inicia la ruta.
        IF v_id_prestamo_detalle IS NOT NULL
           AND NULLIF(v_item->>'idBalon', '') IS NOT NULL
           AND NULLIF(v_item->>'fechaRetornoPactada', '') IS NOT NULL
        THEN
            v_arr_detalles := jsonb_build_array(
                jsonb_build_object(
                    'idPrestamoDetalle', v_id_prestamo_detalle,
                    'observacion', 'Recojo automático generado al vender el préstamo'
                )
            );

            v_result := bal_crear_recojo(
                v_id_cliente,
                v_id_prestamo,
                NULL,
                NULL,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL::TIME,
                NULL::INTEGER,
                'Recojo automático generado al vender el préstamo',
                v_arr_detalles::JSON,
                p_id_usuario,
                FALSE
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                v_id_prestamo,
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                NULL,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        -- Fase 4 (apunte 1.c.viii) — préstamo con garantía de balón: el cliente deja
        -- su propio cilindro como colateral y se lleva uno de Sarita recargado.
        -- Distinto de v_garantia (dinero): aquí se registra un balón físico nuevo,
        -- de propietario GARANTIA_CLIENTE, con su propia fila de detalle (rol
        -- GARANTIA) enlazada al mismo préstamo que ya tiene el detalle ENTREGADO
        -- creado arriba.
        v_garantia_balon := v_item->'garantiaBalon';
        IF json_typeof(v_garantia_balon) = 'object'
           AND NULLIF(v_garantia_balon->>'codigoBalon', '') IS NOT NULL
        THEN
            v_vigencia_ph_garantia := COALESCE(
                NULLIF(v_garantia_balon->>'vigenciaPruebaHidrostaticaAnios', '')::INTEGER, 5
            );
            v_fecha_ultima_ph_garantia := NULLIF(v_garantia_balon->>'fechaUltimaPruebaHidrostatica', '')::DATE;
            v_fecha_proxima_ph_garantia := CASE
                WHEN v_fecha_ultima_ph_garantia IS NOT NULL
                THEN (v_fecha_ultima_ph_garantia + (v_vigencia_ph_garantia || ' years')::INTERVAL)::DATE
                ELSE NULL
            END;

            v_observacion_balon_garantia := NULLIF(TRIM(COALESCE(v_garantia_balon->>'observacion', '')), '');
            IF v_fecha_proxima_ph_garantia IS NOT NULL AND v_fecha_proxima_ph_garantia < CURRENT_DATE THEN
                v_observacion_balon_garantia := TRIM(
                    COALESCE(v_observacion_balon_garantia || ' — ', '')
                    || 'Prueba hidrostática vencida al recibir en garantía ('
                    || TO_CHAR(v_fecha_proxima_ph_garantia, 'DD/MM/YYYY') || ')'
                );
            END IF;

            SELECT lo.id INTO v_id_propietario_garantia
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'GARANTIA_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_propietario_garantia IS NULL THEN
                RAISE EXCEPTION 'Falta la opción GARANTIA_CLIENTE en el catálogo PropietarioBalon';
            END IF;

            SELECT lo.id INTO v_id_estado_balon_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
            LIMIT 1;

            v_result := bal_crear_balon(
                p_codigo_balon                          => TRIM(v_garantia_balon->>'codigoBalon'),
                p_fecha_registro                        => CURRENT_DATE,
                p_id_almacen                             => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_propietario                        => v_id_propietario_garantia,
                p_id_cliente_propietario                => v_id_cliente,
                p_id_tipo_balon                         => NULLIF(v_garantia_balon->>'idTipoBalon', '')::INTEGER,
                p_id_producto_gas                       => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_id_estado_balon                       => v_id_estado_balon_almacen,
                p_fecha_ultima_prueba_hidrostatica      => v_fecha_ultima_ph_garantia,
                p_vigencia_prueba_hidrostatica_anios    => v_vigencia_ph_garantia,
                p_fecha_proxima_prueba_hidrostatica     => v_fecha_proxima_ph_garantia,
                p_observacion                            => v_observacion_balon_garantia,
                p_numero_serie                          => NULLIF(v_garantia_balon->>'numeroSerie', ''),
                p_id_usuario_auditoria                  => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_balon_garantia := (v_result->'registro'->>'id')::INTEGER;

            IF v_id_balon_garantia IS NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el cilindro de garantía';
            END IF;

            v_mov_garantia := inv_registrar_movimiento(
                p_naturaleza                    => 'BALON',
                p_codigo_tipo_movimiento        => 'ENTRADA_GARANTIA',
                p_id_balon                      => v_id_balon_garantia,
                p_cantidad                      => 1,
                p_id_almacen_destino            => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_cliente                    => v_id_cliente,
                p_codigo_tipo_documento_origen  => 'PRESTAMO',
                p_id_documento_origen           => v_id_prestamo,
                p_glosa                         => 'Cilindro dejado en garantía por el cliente',
                p_id_usuario_auditoria          => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_mov_garantia);

            v_result := bal_crear_prestamo_detalle(
                p_id_prestamo            => v_id_prestamo,
                p_id_balon               => v_id_balon_garantia,
                p_id_producto            => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_observacion            => 'Cilindro recibido en garantía',
                p_id_usuario_auditoria   => p_id_usuario,
                p_rol                    => 'GARANTIA'
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- GRE solo si el usuario lo pidió (opt-in). Sin flag no se emite.
    IF COALESCE(
        NULLIF(p_efectos->>'generarGre', '')::BOOLEAN,
        NULLIF(p_efectos->>'generar_gre', '')::BOOLEAN,
        FALSE
    ) THEN
        PERFORM ven_pos_crear_guia_remision(p_id_comprobante, p_id_usuario);
    END IF;

    -- Alquiler de regulador/accesorio (+ periodo + garantía)
    v_arr := CASE WHEN json_typeof(p_efectos->'alquileres') = 'array' THEN p_efectos->'alquileres' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_alquiler(
            NULL,
            v_id_cliente,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(v_item->>'fechaInicio', '')::DATE,
            NULLIF(v_item->>'fechaFinPactada', '')::DATE,
            NULL,
            COALESCE(NULLIF(v_item->>'tarifaDiaria', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item->>'totalCobrado', '')::NUMERIC, 0),
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_comprobante,
            NULLIF(v_item->>'idProductoRegulador', '')::INTEGER,
            NULLIF(v_item->>'idProductoStock', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_alquiler := (v_result->'registro'->>'id')::INTEGER;
        IF v_id_alquiler IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el alquiler POS';
        END IF;

        v_periodo := v_item->'periodo';
        IF json_typeof(v_periodo) = 'object' THEN
            v_result := bal_registrar_alquiler_periodo(
                v_id_alquiler,
                NULLIF(v_periodo->>'fechaInicio', '')::DATE,
                NULLIF(v_periodo->>'fechaFin', '')::DATE,
                COALESCE(NULLIF(v_periodo->>'monto', '')::NUMERIC, 0),
                NULLIF(v_periodo->>'idProducto', '')::INTEGER,
                p_id_comprobante,
                NULLIF(TRIM(COALESCE(v_periodo->>'observacion', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_id_producto := COALESCE(
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULLIF(v_item->>'idProductoRegulador', '')::INTEGER
            );
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                NULL,
                v_id_producto,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                v_id_alquiler,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- Mantenimientos
    v_arr := CASE WHEN json_typeof(p_efectos->'mantenimientos') = 'array' THEN p_efectos->'mantenimientos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_mantenimiento(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'fechaIngreso', '')::DATE,
            NULLIF(v_item->>'idTipoMantenimiento', '')::INTEGER,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
            COALESCE(NULLIF(v_item->>'costo', '')::NUMERIC, 0),
            FALSE,
            NULL,
            NULL,
            p_id_comprobante,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_usuario,
            NULL,
            NULL,
            NULL,
            NULL
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Baja por venta de cilindro
    v_arr := CASE WHEN json_typeof(p_efectos->'bajas') = 'array' THEN p_efectos->'bajas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_dar_baja_balon(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idMotivoBaja', '')::INTEGER,
            p_id_usuario,
            NULL,
            NULL,
            v_id_cliente,
            p_id_comprobante,
            v_serie,
            v_numero,
            NULLIF(v_item->>'montoVenta', '')::NUMERIC,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'fechaBaja', '')::DATE,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_baja := (v_result->'registro'->>'id')::INTEGER;

        IF COALESCE((v_item->>'aprobar')::BOOLEAN, FALSE) AND v_id_baja IS NOT NULL THEN
            v_result := bal_aprobar_baja_balon(
                v_id_baja,
                p_id_usuario,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;
END;
$function$;
