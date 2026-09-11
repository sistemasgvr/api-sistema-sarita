-- ============================================================
-- Migracion Wave 1: NC recarga sin doble stock, NC RECHAZADO,
--                  planta/recojo y devolucion cancela recojo
-- Fecha: 2026-09-11
--
-- A) ven_crear_comprobante: NC no hace INGRESO PRODUCTO si el
--    origen tenia id_balon (gas se restaura via custodia RECARGA).
--    Tope NC incluye RECHAZADO hasta soft-delete.
-- B) ven_obtener_comprobante: cantidad_nc_previa cuenta RECHAZADO
--    hasta soft-delete.
-- C) ven_revertir_nc_sunat_rechazada (nueva): revertir efectos +
--    soft-delete de NC rechazada por SUNAT.
-- D) bal_registrar_resultado_recojo: no ENTRADA_LLENADO si ya hay
--    ENTRADA_PLANTA_EXTERNA BALON de la OS.
-- E) doc_anular_salida: bloquea con recojo PROGRAMADO/EN_RUTA.
-- F) bal_devolver_prestamo/alquiler_detalle: cancela recojos vivos.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_w1_nc_planta_devolver.sql
-- ============================================================

-- ===== funciones\comprobantes\ven_crear_comprobante.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_crear_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_cliente integer, p_detalles json, p_id_tipo_operacion_sunat integer, p_id_comprobante_origen integer, p_id_motivo_nota integer, p_id_tipo_movimiento integer, p_id_tipo_venta integer, p_fecha_vencimiento date, p_tipo_cambio numeric, p_id_sucursal integer, p_id_almacen integer, p_id_condicion_pago integer, p_id_moneda integer, p_id_medio_pago integer, p_glosa character varying, p_observaciones character varying, p_periodo_contable character varying, p_operacion character varying, p_id_estado integer, p_cuotas json, p_id_usuario_auditoria integer, p_origen_pos character varying, p_efectos_pos json);
DROP FUNCTION IF EXISTS ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_cliente integer, p_detalles json, p_id_tipo_operacion_sunat integer, p_id_comprobante_origen integer, p_id_motivo_nota integer, p_id_tipo_movimiento integer, p_id_tipo_venta integer, p_fecha_vencimiento date, p_tipo_cambio numeric, p_id_sucursal integer, p_id_almacen integer, p_id_condicion_pago integer, p_id_moneda integer, p_id_medio_pago integer, p_glosa character varying, p_observaciones character varying, p_periodo_contable character varying, p_operacion character varying, p_id_estado integer, p_cuotas json, p_id_usuario_auditoria integer, p_origen_pos character varying, p_efectos_pos json, p_pagos json);

CREATE OR REPLACE FUNCTION ven_crear_comprobante(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying DEFAULT NULL::character varying, p_fecha date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_detalles json DEFAULT '[]'::json, p_id_tipo_operacion_sunat integer DEFAULT NULL::integer, p_id_comprobante_origen integer DEFAULT NULL::integer, p_id_motivo_nota integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_tipo_venta integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_tipo_cambio numeric DEFAULT 3.5, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_observaciones character varying DEFAULT NULL::character varying, p_periodo_contable character varying DEFAULT NULL::character varying, p_operacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_cuotas json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_origen_pos character varying DEFAULT NULL::character varying, p_efectos_pos json DEFAULT NULL::json, p_pagos json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_err_pagos TEXT;
    v_id INTEGER;
    v_id_detalle INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_items_sin_kardex INTEGER[];
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_sub_total NUMERIC(12,4) := 0;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_sunat INTEGER;
    v_id_estado_doc INTEGER;
    v_codigo_tipo VARCHAR;
    v_numero_cuota INTEGER;
    v_id_estado_cuota INTEGER;
    v_serie_origen VARCHAR;
    v_familia_origen CHAR(1);
    v_afecta_stock BOOLEAN;
    v_requiere_stock BOOLEAN := FALSE;
    v_es_conversion_vsd BOOLEAN := FALSE;
    v_es_nota_credito BOOLEAN := FALSE;
    v_codigo_tipo_origen VARCHAR;
    v_id_almacen_origen INTEGER;
    v_id_tipo_mov_inv INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_glosa_mov VARCHAR;
    v_qty_origen NUMERIC(12,4);
    v_qty_nc_previas NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_estado_sunat_origen VARCHAR;
    v_id_afectacion_igv INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
    v_es_servicio BOOLEAN;
    v_err_caja TEXT;
    v_dias_credito INTEGER := 0;
    v_numero_cuotas INTEGER := 0;
    v_dia_mes_pago INTEGER;
    v_fecha_venc_cxc DATE;
    v_fecha_primera_cuota DATE;
    v_id_tipo_cobrar INTEGER;
    v_cxc_result JSON;
    v_mes_base DATE;
    v_ultimo_dia_mes DATE;
    v_total_origen NUMERIC(12,4);
    v_id_balon INTEGER;
    v_nombre_estado_balon VARCHAR;
    v_id_estado_pendiente_envio INTEGER;
    v_id_estado_disponible INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del comprobante es obligatoria', 'registro', NULL);
    END IF;

    -- Si no viene sucursal, se toma del almacén (caja es por fecha + sucursal).
    IF p_id_sucursal IS NULL AND p_id_almacen IS NOT NULL THEN
        SELECT a.id_sucursal INTO p_id_sucursal
        FROM gen_almacen a
        WHERE a.id = p_id_almacen
          AND a.estado = 1
        LIMIT 1;
    END IF;

    -- Operación del día: requiere caja ABIERTA (arqueo / control operativo)
    v_err_caja := fin_caja_assert_abierta(p_fecha, p_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_comprobante;

    -- Serie: CPE SUNAT = 4 caracteres; venta sin documento (VSD) = 5 (ej. VSD01). Legacy NV01 = 4.
    IF v_codigo_tipo IN ('NV', 'VSD') THEN
        IF NOT (
            (char_length(v_serie) = 5 AND left(v_serie, 3) = 'VSD')
            OR (char_length(v_serie) = 4 AND left(v_serie, 2) = 'NV')
        ) THEN
            RETURN json_build_object(
                'error',
                'La venta sin documento debe usar serie VSD## (ej. VSD01)',
                'registro',
                NULL
            );
        END IF;
    ELSIF char_length(v_serie) <> 4 THEN
        RETURN json_build_object(
            'error',
            'La serie electrónica debe tener 4 caracteres (ej. F001, B001, FC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND left(v_serie, 1) NOT IN ('F', 'B') THEN
        RETURN json_build_object(
            'error',
            'La nota de crédito/débito debe usar serie que inicie con F o B según el comprobante origen (ej. FC01 / BC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NULL THEN
        RETURN json_build_object('error', 'La nota de crédito/débito requiere el comprobante de origen', 'registro', NULL);
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante_origen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de origen no existe o está inactivo', 'registro', NULL);
    END IF;

    -- NC/ND solo sobre CPE ACEPTADO (alineado a FE puedeNotaCredito).
    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT es.nombre
        INTO v_estado_sunat_origen
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        WHERE c.id = p_id_comprobante_origen
          AND c.estado = 1;

        IF COALESCE(v_estado_sunat_origen, '') <> 'ACEPTADO' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede crear nota de crédito/débito sobre un comprobante ACEPTADO por SUNAT',
                'registro',
                NULL
            );
        END IF;
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');

    -- Conversión VSD/NV → boleta/factura: el stock ya se descontó en el origen
    IF p_id_comprobante_origen IS NOT NULL AND v_codigo_tipo IN ('01', '03') THEN
        SELECT lo.descripcion, c.id_almacen
        INTO v_codigo_tipo_origen, v_id_almacen_origen
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON c.id_tipo_comprobante = lo.id
        WHERE c.id = p_id_comprobante_origen AND c.estado = 1;

        IF v_codigo_tipo_origen IN ('NV', 'VSD') THEN
            v_es_conversion_vsd := TRUE;

            IF EXISTS (
                SELECT 1
                FROM ven_comprobante
                WHERE id_comprobante_origen = p_id_comprobante_origen
                  AND estado = 1
            ) THEN
                RETURN json_build_object(
                    'error',
                    'Esta venta sin documento ya fue convertida a boleta/factura',
                    'registro',
                    NULL
                );
            END IF;

            IF p_id_almacen IS NULL THEN
                p_id_almacen := v_id_almacen_origen;
            ELSIF v_id_almacen_origen IS NOT NULL AND p_id_almacen <> v_id_almacen_origen THEN
                RETURN json_build_object(
                    'error',
                    'Al convertir, el almacén debe ser el mismo de la venta sin documento',
                    'registro',
                    NULL
                );
            END IF;
        END IF;
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT UPPER(TRIM(serie)) INTO v_serie_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        v_familia_origen := left(COALESCE(v_serie_origen, ''), 1);
        IF v_familia_origen IN ('F', 'B') AND left(v_serie, 1) <> v_familia_origen THEN
            RETURN json_build_object(
                'error',
                format(
                    'La serie de la nota debe iniciar con %s igual que el comprobante origen (%s)',
                    v_familia_origen,
                    v_serie_origen
                ),
                'registro',
                NULL
            );
        END IF;
    END IF;

    -- No confiar en el correlativo del cliente: se asigna bajo candado de serie en la TX.
    SELECT (ven_obtener_siguiente_numero(p_id_tipo_comprobante, v_serie)->>'numero')
    INTO v_numero;

    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo del comprobante', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_comprobante
        WHERE UPPER(TRIM(serie)) = v_serie AND numero = v_numero
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un comprobante con la serie ' || v_serie || ' y número ' || v_numero,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoSunat'
      AND lo.nombre = CASE
        WHEN v_codigo_tipo IN ('NV', 'VSD') THEN 'NO_APLICA'
        ELSE 'PENDIENTE'
      END
      AND lo.estado = 1
    LIMIT 1;

    IF p_id_estado IS NOT NULL THEN
        v_id_estado_doc := p_id_estado;
    ELSE
        SELECT lo.id INTO v_id_estado_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoDocumento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_estado_cuota
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

        IF v_id_producto IS NULL THEN
            RETURN json_build_object('error', 'Cada detalle debe indicar id_producto', 'registro', NULL);
        END IF;

        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad de cada detalle debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pro_producto WHERE id = v_id_producto AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error',
                'El producto ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' no existe o está inactivo',
                'registro',
                NULL
            );
        END IF;

        -- Cilindro ya comprometido / fuera de stock entregable: no venderlo de nuevo
        -- (cierra el hueco hasta que la OS lo marque; ver reserva PENDIENTE_ENVIO al final).
        v_id_balon := NULLIF((v_detalle->>'id_balon')::INTEGER, 0);
        IF v_id_balon IS NOT NULL AND NOT v_es_nota_credito THEN
            SELECT UPPER(TRIM(COALESCE(eb.nombre, '')))
            INTO v_nombre_estado_balon
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1;

            IF NOT FOUND THEN
                RETURN json_build_object(
                    'error',
                    format('El cilindro #%s no existe o está inactivo', v_id_balon),
                    'registro', NULL
                );
            END IF;

            IF v_nombre_estado_balon IN (
                'PENDIENTE_ENVIO', 'EN_TRANSITO', 'EN_MANTENIMIENTO',
                'DADO_DE_BAJA', 'ROBO', 'PRESTADO_CLIENTE', 'EN_PODER_CLIENTE',
                'ALQUILADO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER'
            ) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'El cilindro no está disponible para venta (estado %s)',
                        LOWER(REPLACE(v_nombre_estado_balon, '_', ' '))
                    ),
                    'registro', NULL
                );
            END IF;
        END IF;

        SELECT
            REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
            COALESCE(p.es_gas, FALSE),
            COALESCE(p.es_servicio, FALSE),
            COALESCE(p.afecta_stock, FALSE)
        INTO v_nombre_unidad, v_es_gas, v_es_servicio, v_afecta_stock
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.id = v_id_producto;

        -- Gases (m³) pueden ser decimales aunque la U.M. esté mal catalogada como UNID.
        IF NOT COALESCE(v_es_gas, FALSE)
           AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
           AND v_cantidad <> TRUNC(v_cantidad)
        THEN
            RETURN json_build_object(
                'error',
                'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' debe ser entera (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;

        -- Servicios, alquiler (tarifa) y garantía no descuentan stock.
        IF NOT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion') THEN
            v_afecta_stock := FALSE;
        END IF;

        -- ND (08) no mueve stock. Conversión VSD→CPE reutiliza el descuento previo.
        IF v_afecta_stock AND NOT v_es_conversion_vsd AND v_codigo_tipo <> '08' THEN
            v_requiere_stock := TRUE;
        END IF;

        -- precio_unitario del catálogo ya incluye IGV
        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        -- Sin afectación: default explícito a Gravado 10 (no tratar NULL como no gravado).
        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;

            IF v_id_afectacion_igv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Cada detalle debe indicar id_afectacion_igv (no se encontró Gravado 10 en catálogo)',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
            IF v_codigo_afectacion = '20' THEN
                v_exonerado_total := v_exonerado_total + v_valor_linea;
            END IF;
        END IF;

        v_descuento_total := v_descuento_total + v_descuento_linea;
        v_valor_venta_total := v_valor_venta_total + v_valor_linea;
        v_igv_total := v_igv_total + v_impuesto_linea;
        v_sub_total := v_sub_total + v_importe_linea;
        v_total_importe := v_total_importe + v_importe_linea;
    END LOOP;

    -- Cap NC (siempre, aunque no mueva kardex): qty ≤ origen − NCs previas por producto.
    IF v_es_nota_credito THEN
        FOR v_id_producto, v_cantidad IN
            SELECT
                (value->>'id_producto')::INTEGER,
                SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
            FROM json_array_elements(p_detalles)
            GROUP BY 1
        LOOP
            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_origen
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = p_id_comprobante_origen
              AND d.id_producto = v_id_producto
              AND d.estado = 1;

            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_nc_previas
            FROM ven_comprobante nc
            INNER JOIN gen_lista_opciones tc
                ON tc.id = nc.id_tipo_comprobante
               AND tc.descripcion = '07'
            INNER JOIN ven_comprobante_detalle d
                ON d.id_comprobante = nc.id
               AND d.estado = 1
               AND d.id_producto = v_id_producto
            LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
            WHERE nc.id_comprobante_origen = p_id_comprobante_origen
              AND nc.estado = 1
              -- RECHAZADO cuenta hasta soft-delete (ven_revertir_nc_sunat_rechazada).
              AND COALESCE(es.nombre, '') NOT IN ('BAJA');

            IF v_cantidad > (v_qty_origen - v_qty_nc_previas) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'La cantidad a acreditar de %s (%s) supera lo disponible para devolver (%s). Vendida: %s, ya acreditada: %s',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        v_cantidad,
                        GREATEST(v_qty_origen - v_qty_nc_previas, 0),
                        v_qty_origen,
                        v_qty_nc_previas
                    ),
                    'registro',
                    NULL
                );
            END IF;
        END LOOP;
    END IF;

    IF v_requiere_stock THEN
        IF p_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'Debe indicar el almacén para descontar stock de los productos',
                'registro',
                NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        -- NC restaura stock (INGRESO); ventas descuentan (SALIDA)
        IF v_es_nota_credito THEN
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo de movimiento de inventario INGRESO',
                    'registro',
                    NULL
                );
            END IF;
        ELSE
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo de movimiento de inventario SALIDA',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        -- Validar disponibilidad agrupando por producto (varias líneas del mismo gas).
        IF NOT v_es_nota_credito THEN
            FOR v_id_producto, v_cantidad IN
                SELECT
                    (value->>'id_producto')::INTEGER,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                FROM json_array_elements(p_detalles)
                GROUP BY 1
            LOOP
                IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                    CONTINUE;
                END IF;

                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_cantidad THEN
                    RETURN json_build_object(
                        'error',
                        format(
                            'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                            COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                            COALESCE(v_stock_disponible, 0),
                            v_cantidad
                        ),
                        'registro',
                        NULL
                    );
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Gas también se valida contra pro_stock (bloque de capacidad de cilindros eliminado en F1).

    -- Ventas a crédito sin medio de pago explícito (el POS no lo pide: "excluir-credito"
    -- + "medio-requerido = !esVentaCredito", el cobro se registra después en CxC): sin
    -- esto, id_medio_pago queda NULL y fin_caja_calcular_totales / ven_pagos_de_comprobante
    -- lo tratan como EFECTIVO (COALESCE(..., v_efectivo_id)), contando la venta entera como
    -- "ventasContado" en vez de "ventasCredito" en la card de caja.
    IF p_id_medio_pago IS NULL AND p_id_condicion_pago IS NOT NULL THEN
        SELECT o.id INTO p_id_medio_pago
        FROM gen_condicion_pago cp
        JOIN gen_lista_opciones o ON UPPER(o.nombre) = 'CREDITO' AND o.estado = 1
        JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
        WHERE cp.id = p_id_condicion_pago
          AND (COALESCE(cp.dias_credito, 0) > 0 OR COALESCE(cp.numero_cuotas, 0) > 1)
        LIMIT 1;
    END IF;

    INSERT INTO ven_comprobante (
        id_tipo_comprobante, serie, numero,
        id_estado_sunat, id_tipo_operacion_sunat,
        id_comprobante_origen, id_motivo_nota,
        id_tipo_movimiento, id_tipo_venta,
        fecha, fecha_vencimiento, tipo_cambio,
        id_cliente, id_sucursal, id_almacen,
        id_condicion_pago, id_moneda, id_medio_pago,
        sub_total, descuento, valor_venta, igv, total_importe,
        exonerado, glosa, observaciones,
        periodo_contable, operacion, origen_pos, id_estado,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_comprobante, v_serie, v_numero,
        v_id_estado_sunat, p_id_tipo_operacion_sunat,
        p_id_comprobante_origen, p_id_motivo_nota,
        p_id_tipo_movimiento, p_id_tipo_venta,
        p_fecha, p_fecha_vencimiento, COALESCE(p_tipo_cambio, 3.5),
        p_id_cliente, p_id_sucursal, p_id_almacen,
        p_id_condicion_pago, p_id_moneda, p_id_medio_pago,
        v_sub_total, v_descuento_total, v_valor_venta_total, v_igv_total, v_total_importe,
        v_exonerado_total, p_glosa, p_observaciones,
        p_periodo_contable, p_operacion, NULLIF(TRIM(p_origen_pos), ''), v_id_estado_doc,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_item := 0;
    v_items_sin_kardex := ARRAY[]::INTEGER[];
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        -- Líneas cuyo inventario ya mueve otro proceso (recarga de mostrador: el gas
        -- lo descuenta el movimiento del balón, con la capacidad real). El bucle de
        -- stock lee las filas ya insertadas, así que la marca se propaga por N° de ítem.
        IF COALESCE((v_detalle->>'no_mueve_kardex')::BOOLEAN, FALSE) THEN
            v_items_sin_kardex := v_items_sin_kardex
                || COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item);
        END IF;

        v_id_producto := (v_detalle->>'id_producto')::INTEGER;
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
        -- precio_unitario del catálogo ya incluye IGV
        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
        END IF;

        INSERT INTO ven_comprobante_detalle (
            id_comprobante, item, id_producto, descripcion, id_unidad_medida,
            cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
            id_afectacion_igv, impuesto, importe,
            id_balon, capacidad_cilindro, id_estado_cilindro,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id,
            COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
            v_id_producto,
            NULLIF(v_detalle->>'descripcion', ''),
            NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
            v_cantidad,
            v_precio_unitario,
            v_descuento_linea,
            v_valor_linea,
            v_porcentaje_igv,
            v_id_afectacion_igv,
            v_impuesto_linea,
            v_importe_linea,
            NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
            NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
            NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    IF v_es_conversion_vsd THEN
        -- Reasignar movimientos del VSD al CPE y ajustar solo diferencias de cantidad
        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        v_mov_result := inv_repuntar_documento(
            p_codigo_tipo_documento_origen_actual => ven_resolver_tipo_documento_ref(v_codigo_tipo_origen, v_nombre_tipo_venta),
            p_id_documento_origen_actual          => p_id_comprobante_origen,
            p_codigo_tipo_documento_origen_nuevo  => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
            p_id_documento_origen_nuevo           => v_id,
            p_glosa                               => COALESCE(
                NULLIF(TRIM(p_glosa), ''),
                format('Salida por comprobante %s-%s (desde venta sin documento)', v_serie, v_numero)
            ),
            p_id_usuario_auditoria                => p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        FOR v_id_producto, v_qty_origen, v_qty_nueva IN
            SELECT
                COALESCE(o.id_producto, n.id_producto) AS id_producto,
                COALESCE(o.cantidad, 0) AS qty_origen,
                COALESCE(n.cantidad, 0) AS qty_nueva
            FROM (
                SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                FROM ven_comprobante_detalle d
                INNER JOIN pro_producto p ON p.id = d.id_producto
                WHERE d.id_comprobante = p_id_comprobante_origen
                  AND d.estado = 1
                  AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                GROUP BY d.id_producto
            ) o
            FULL OUTER JOIN (
                SELECT
                    (value->>'id_producto')::INTEGER AS id_producto,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                FROM json_array_elements(p_detalles)
                GROUP BY (value->>'id_producto')::INTEGER
            ) n ON n.id_producto = o.id_producto
            INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
            WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
        LOOP
            v_delta_stock := v_qty_nueva - v_qty_origen;
            IF v_delta_stock = 0 THEN
                CONTINUE;
            END IF;

            IF v_delta_stock > 0 THEN
                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                    RAISE EXCEPTION
                        'Stock insuficiente del producto % en el almacén (disponible: %, solicitado: %)',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        COALESCE(v_stock_disponible, 0),
                        v_delta_stock;
                END IF;

                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'SALIDA',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => v_delta_stock,
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversión %s-%s (+)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            ELSE
                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'INGRESO',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => ABS(v_delta_stock),
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversión %s-%s (-)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            END IF;

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END LOOP;
    ELSIF v_requiere_stock THEN
        v_glosa_mov := COALESCE(
            NULLIF(TRIM(p_glosa), ''),
            CASE
                WHEN v_es_nota_credito THEN
                    format('Ingreso por nota de crédito %s-%s', v_serie, v_numero)
                ELSE
                    format('Salida por comprobante %s-%s', v_serie, v_numero)
            END
        );

        FOR v_id_detalle, v_id_producto, v_cantidad, v_detalle IN
            SELECT d.id, d.id_producto, d.cantidad, to_json(d.*)
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id AND d.estado = 1
            ORDER BY d.id
        LOOP
            SELECT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion')
            INTO v_afecta_stock;

            -- Líneas marcadas como "no_mueve_kardex" en p_detalles: otro proceso ya
            -- descuenta ese inventario (recarga de mostrador: el movimiento del balón
            -- lleva la capacidad real). Sin esto la venta descontaba además su propia
            -- cantidad y el gas salía del stock dos veces (apunte 1.c.iv.6).
            IF (v_detalle->>'item')::INTEGER = ANY(v_items_sin_kardex) THEN
                CONTINUE;
            END IF;

            -- NC de recarga: el origen no movió kardex de producto (solo RECARGA
            -- vía balón). ven_cerrar_custodia revierte esa RECARGA; un INGRESO
            -- aquí duplicaría el gas.
            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                    SELECT 1
                    FROM ven_comprobante_detalle od
                    WHERE od.id_comprobante = p_id_comprobante_origen
                      AND od.estado = 1
                      AND od.id_producto = v_id_producto
                      AND od.id_balon IS NOT NULL
               ) THEN
                CONTINUE;
            END IF;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            -- NC de recarga (gas+cilindro): el gas se restaura al cerrar custodia
            -- (RECARGA revert). Un INGRESO PRODUCTO aquí duplicaría stock.
            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                   SELECT 1
                   FROM ven_comprobante_detalle od
                   WHERE od.id_comprobante = p_id_comprobante_origen
                     AND od.id_producto = v_id_producto
                     AND od.id_balon IS NOT NULL
                     AND od.estado = 1
               )
            THEN
                CONTINUE;
            END IF;

            v_mov_result := inv_registrar_movimiento(
                p_naturaleza => 'PRODUCTO',
                p_codigo_tipo_movimiento => CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                p_fecha => p_fecha,
                p_id_producto => v_id_producto,
                p_cantidad => v_cantidad,
                p_id_almacen_origen => p_id_almacen,
                p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                p_id_documento_origen => v_id,
                p_glosa => v_glosa_mov,
                p_id_usuario_auditoria => p_id_usuario_auditoria,
                p_id_documento_detalle => v_id_detalle
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
            IF COALESCE((v_mov_result->>'creado')::boolean, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registró el movimiento de stock (duplicado) para el producto %', v_id_producto;
            END IF;
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL AND json_typeof(p_cuotas) = 'array' THEN
        FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
        LOOP
            v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
            IF v_numero_cuota <= 0 THEN
                CONTINUE;
            END IF;

            INSERT INTO ven_cuotas (
                id_comprobante, numero_cuota, fecha_vencimiento, monto,
                monto_pagado, id_estado,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_numero_cuota,
                (v_cuota->>'fecha_vencimiento')::DATE,
                COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- Crédito / cuotas: genera CxC vinculada al comprobante según condición de pago.
    IF NOT v_es_nota_credito
       AND p_id_condicion_pago IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        SELECT
            COALESCE(cp.dias_credito, 0),
            COALESCE(cp.numero_cuotas, 0),
            cp.dia_mes_pago
        INTO v_dias_credito, v_numero_cuotas, v_dia_mes_pago
        FROM gen_condicion_pago cp
        WHERE cp.id = p_id_condicion_pago
          AND cp.estado = 1;

        IF v_dias_credito > 0 OR v_numero_cuotas > 1 THEN
            IF EXISTS (
                SELECT 1
                FROM cli_clientes c
                WHERE c.id = p_id_cliente
                  AND UPPER(COALESCE(c.codigo_interno, '')) = 'CVARIOS'
            ) THEN
                RAISE EXCEPTION
                    'No se puede vender a crédito a Clientes Varios. Selecciona un cliente identificado.';
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM fin_cuenta fc
                WHERE fc.id_comprobante_venta = v_id
                  AND fc.estado = 1
            ) THEN
                IF v_numero_cuotas > 1 THEN
                    IF v_dia_mes_pago IS NULL OR v_dia_mes_pago < 1 OR v_dia_mes_pago > 31 THEN
                        RAISE EXCEPTION
                            'La condición de pago en cuotas requiere día del mes a cobrar (1 a 31).';
                    END IF;

                    -- Primera cuota: fecha vencimiento explícita, o emisión + días, o próximo día_mes_pago
                    IF p_fecha_vencimiento IS NOT NULL THEN
                        v_fecha_primera_cuota := p_fecha_vencimiento;
                    ELSIF v_dias_credito > 0 THEN
                        v_fecha_primera_cuota := COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito;
                    ELSE
                        v_mes_base := date_trunc('month', COALESCE(p_fecha, CURRENT_DATE))::date;
                        v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                        v_fecha_primera_cuota := LEAST(
                            (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                            v_ultimo_dia_mes
                        );
                        IF v_fecha_primera_cuota < COALESCE(p_fecha, CURRENT_DATE) THEN
                            v_mes_base := (v_mes_base + INTERVAL '1 month')::date;
                            v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                            v_fecha_primera_cuota := LEAST(
                                (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                                v_ultimo_dia_mes
                            );
                        END IF;
                    END IF;

                    UPDATE ven_comprobante
                    SET fecha_vencimiento = v_fecha_primera_cuota
                    WHERE id = v_id
                      AND fecha_vencimiento IS NULL;

                    v_cxc_result := fin_crear_cuenta_cuotas(
                        'COBRAR',
                        p_id_cliente,
                        NULL,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_total_importe,
                        v_numero_cuotas,
                        v_fecha_primera_cuota,
                        v_dia_mes_pago,
                        format(
                            'CxC en %s cuotas (día %s) %s-%s',
                            v_numero_cuotas,
                            v_dia_mes_pago,
                            v_serie,
                            v_numero
                        ),
                        NULL,
                        NULL,
                        NULL,
                        v_serie || '-' || v_numero,
                        p_id_usuario_auditoria,
                        v_id
                    );

                    IF v_cxc_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_cxc_result->>'error';
                    END IF;
                ELSE
                    -- Crédito simple (un solo vencimiento)
                    v_fecha_venc_cxc := COALESCE(
                        p_fecha_vencimiento,
                        (COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito)
                    );

                    IF p_fecha_vencimiento IS NULL THEN
                        UPDATE ven_comprobante
                        SET fecha_vencimiento = v_fecha_venc_cxc
                        WHERE id = v_id;
                    END IF;

                    SELECT glo.id
                    INTO v_id_tipo_cobrar
                    FROM gen_lista_opciones glo
                    JOIN gen_lista gl ON gl.id = glo.id_lista
                    WHERE gl.nombre = 'TipoCuentaFinanciera'
                      AND glo.nombre = 'COBRAR'
                      AND glo.estado = 1
                    LIMIT 1;

                    IF v_id_tipo_cobrar IS NULL THEN
                        RAISE EXCEPTION
                            'No está configurado el tipo de cuenta COBRAR (TipoCuentaFinanciera).';
                    END IF;

                    INSERT INTO fin_cuenta (
                        id_tipo_cuenta,
                        id_tercero,
                        id_comprobante_venta,
                        numero_comprobante,
                        fecha_emision,
                        fecha_vencimiento,
                        monto_pendiente,
                        monto_abonado,
                        monto_saldo,
                        descripcion,
                        id_usuario_creacion,
                        id_usuario_modificacion
                    ) VALUES (
                        v_id_tipo_cobrar,
                        p_id_cliente,
                        v_id,
                        v_serie || '-' || v_numero,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_fecha_venc_cxc,
                        v_total_importe,
                        0,
                        v_total_importe,
                        format(
                            'CxC por venta a crédito (%s días) %s-%s',
                            v_dias_credito,
                            v_serie,
                            v_numero
                        ),
                        p_id_usuario_auditoria,
                        p_id_usuario_auditoria
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_es_nota_credito
       AND p_id_comprobante_origen IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        PERFORM fin_abonar_por_nota_credito(
            p_id_comprobante_origen,
            v_id,
            v_total_importe,
            p_id_usuario_auditoria
        );

        SELECT total_importe INTO v_total_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        IF COALESCE(v_total_importe, 0) >= COALESCE(v_total_origen, 0) - 0.05
           OR EXISTS (
               SELECT 1
               FROM ven_comprobante_detalle d
               WHERE d.id_comprobante = v_id
                 AND d.estado = 1
                 AND d.id_balon IS NOT NULL
           )
        THEN
            PERFORM ven_cerrar_custodia_comprobante(
                p_id_comprobante_origen,
                p_id_usuario_auditoria
            );
        END IF;
    END IF;

    IF p_efectos_pos IS NOT NULL AND p_efectos_pos::TEXT NOT IN ('null', '{}', '[]') THEN
        PERFORM ven_aplicar_efectos_pos(v_id, p_efectos_pos, p_id_usuario_auditoria);
    END IF;

    -- ------------------------------------------------------------
    -- Reserva logística al vender (Approach A)
    --
    -- Entre la venta y la OS el cilindro no debe seguir DISPONIBLE (doble venta).
    -- Solo se marcan los que siguen DISPONIBLE tras efectos_pos: los de préstamo
    -- ya pasaron a PRESTADO_CLIENTE y no se tocan aquí.
    -- doc_crear_desde_venta usa el mismo EstadoBalon.PENDIENTE_ENVIO y es
    -- idempotente si la reserva ya existía.
    -- ------------------------------------------------------------
    IF NOT v_es_nota_credito
       AND EXISTS (
           SELECT 1
           FROM ven_comprobante_detalle d
           WHERE d.id_comprobante = v_id
             AND d.estado = 1
             AND d.id_balon IS NOT NULL
             AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
       )
    THEN
        SELECT lo.id INTO v_id_estado_pendiente_envio
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pendiente_envio IS NULL THEN
            RAISE EXCEPTION 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon';
        END IF;

        SELECT lo.id INTO v_id_estado_disponible
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_disponible IS NOT NULL THEN
            UPDATE bal_balon b
            SET id_estado_balon = v_id_estado_pendiente_envio,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id
              AND d.estado = 1
              AND d.id_balon = b.id
              AND b.estado = 1
              AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
              AND b.id_estado_balon = v_id_estado_disponible;
        END IF;
    END IF;

    -- Fase 3: cobro multi-medio. Va al final, cuando total_importe ya está
    -- calculado, porque la suma de los pagos se valida contra él.
    v_err_pagos := ven_sincronizar_pagos_comprobante(v_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;


-- ===== funciones\comprobantes\ven_obtener_comprobante.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_obtener_comprobante
-- Overloads: 1
--
-- Actualizada por database_sql/migraciones/20260905_reparto_desde_orden_salida.sql:
-- el reparto se alcanza tambien por la orden de salida de la venta.
DROP FUNCTION IF EXISTS ven_obtener_comprobante(p_id integer);

CREATE OR REPLACE FUNCTION ven_obtener_comprobante(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_cuotas JSON;
    v_pagos JSON;
    v_prestamos JSON;
    v_garantias JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_tipo_operacion_sunat,
            tos.nombre AS nombre_tipo_operacion_sunat,
            tos.descripcion AS codigo_tipo_operacion_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.ticket_sunat,
            c.hash_documento,
            c.xml_firmado,
            c.cdr_respuesta,
            c.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            c.id_tipo_venta,
            tv.nombre AS nombre_tipo_venta,
            c.fecha,
            c.fecha_vencimiento,
            c.tipo_cambio,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_sucursal,
            su.nombre AS nombre_sucursal,
            c.id_almacen,
            al.nombre AS nombre_almacen,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            COALESCE(cp.dias_credito, 0) AS dias_credito,
            COALESCE(cp.numero_cuotas, 0) AS numero_cuotas,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            mo.descripcion AS codigo_moneda,
            c.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            c.sub_total,
            c.descuento,
            c.valor_venta,
            c.igv,
            c.total_importe,
            c.anticipos,
            c.exonerado,
            c.glosa,
            c.observaciones,
            c.periodo_contable,
            c.operacion,
            c.origen_pos,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            act.nombre_chofer_responsable,
            (act.id IS NOT NULL) AS tiene_actividad,
            -- Orden de salida vigente de esta venta: el detalle del comprobante
            -- muestra «Ver orden» en vez de «Generar» cuando ya existe.
            docsal.id AS id_doc_salida,
            docsal.numero AS numero_doc_salida
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones tos ON c.id_tipo_operacion_sunat = tos.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN gen_lista_opciones tm ON c.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_sucursal su ON c.id_sucursal = su.id
        LEFT JOIN gen_almacen al ON c.id_almacen = al.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN gen_lista_opciones mp ON c.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad,
                TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            LEFT JOIN gen_chofer ch ON ch.id = a.id_chofer_responsable
            -- El reparto se programa desde la orden de salida, que es lo que
            -- realmente sale a la calle, asi que cuelga de doc_salida y no del
            -- comprobante. La venta lo sigue mostrando alcanzandolo por JOIN a
            -- traves de su orden. Se conserva la rama por id_comprobante para
            -- los repartos creados antes de ese cambio.
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        LEFT JOIN LATERAL (
            SELECT d.id, d.numero
            FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = c.id
              AND d.estado = 1
              AND ec.nombre <> 'ANULADA'
            ORDER BY d.id DESC
            LIMIT 1
        ) docsal ON TRUE
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- `es_linea_garantia` marca las líneas que el POS antiguo insertaba para
    -- cobrar la garantía dentro de la venta. Desde este cambio ya no se crean,
    -- pero los comprobantes emitidos antes las conservan: la bandera deja que el
    -- detalle, el ticket y el mapper de SUNAT las traten como garantía sin que
    -- cada uno repita la comparación de texto por su cuenta. Es el mismo
    -- criterio que ya usaba ven_producto_mueve_kardex_venta para no descontar
    -- stock por ellas.
    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_comprobante,
            d.item,
            d.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            d.descripcion,
            d.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            d.cantidad,
            COALESCE((
                SELECT SUM(nd.cantidad)
                FROM ven_comprobante nc
                INNER JOIN gen_lista_opciones tc
                    ON tc.id = nc.id_tipo_comprobante
                   AND tc.descripcion = '07'
                INNER JOIN ven_comprobante_detalle nd
                    ON nd.id_comprobante = nc.id
                   AND nd.estado = 1
                   AND nd.id_producto = d.id_producto
                LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                WHERE nc.id_comprobante_origen = p_id
                  AND nc.estado = 1
                  -- RECHAZADO cuenta hasta soft-delete (ven_revertir_nc_sunat_rechazada).
                  AND COALESCE(es.nombre, '') NOT IN ('BAJA')
            ), 0) AS cantidad_nc_previa,
            GREATEST(
                d.cantidad - COALESCE((
                    SELECT SUM(nd.cantidad)
                    FROM ven_comprobante nc
                    INNER JOIN gen_lista_opciones tc
                        ON tc.id = nc.id_tipo_comprobante
                       AND tc.descripcion = '07'
                    INNER JOIN ven_comprobante_detalle nd
                        ON nd.id_comprobante = nc.id
                       AND nd.estado = 1
                       AND nd.id_producto = d.id_producto
                    LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                    WHERE nc.id_comprobante_origen = p_id
                      AND nc.estado = 1
                      AND COALESCE(es.nombre, '') NOT IN ('BAJA')
                ), 0),
                0
            ) AS cantidad_disponible_nc,
            d.precio_unitario,
            d.descuento,
            d.valor_venta,
            d.porcentaje_igv,
            d.id_afectacion_igv,
            ai.nombre AS nombre_afectacion_igv,
            ai.descripcion AS codigo_afectacion_igv,
            d.impuesto,
            d.importe,
            d.id_balon,
            b.codigo_balon,
            d.capacidad_cilindro,
            d.id_estado_cilindro,
            ec.nombre AS nombre_estado_cilindro,
            (COALESCE(d.descripcion, '') ~* 'garant[ií]a') AS es_linea_garantia,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON d.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON d.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones ai ON d.id_afectacion_igv = ai.id
        LEFT JOIN bal_balon b ON d.id_balon = b.id
        LEFT JOIN gen_lista_opciones ec ON d.id_estado_cilindro = ec.id
        WHERE d.id_comprobante = p_id AND d.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(q) ORDER BY q.numero_cuota), '[]'::JSON) INTO v_cuotas
    FROM (
        SELECT
            q.id,
            q.id_comprobante,
            q.numero_cuota,
            q.fecha_vencimiento,
            q.monto,
            q.monto_pagado,
            q.id_estado,
            eq.nombre AS nombre_estado,
            q.estado,
            q.fecha_creacion,
            q.fecha_modificacion
        FROM ven_cuotas q
        LEFT JOIN gen_lista_opciones eq ON q.id_estado = eq.id
        WHERE q.id_comprobante = p_id AND q.estado = 1
    ) q;

    -- Fase 3: desglose del cobro. Solo las líneas reales de ven_comprobante_pago;
    -- si la venta no tiene ninguna, el array va vacío y el frontend cae al
    -- medio de pago de la cabecera, que es donde estaba el dato antes.
    SELECT COALESCE(json_agg(row_to_json(pg) ORDER BY pg.item), '[]'::JSON) INTO v_pagos
    FROM (
        SELECT
            pp.id,
            pp.item,
            pp.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            pp.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            pp.monto,
            pp.numero_operacion,
            pp.referencia,
            pp.observacion
        FROM ven_comprobante_pago pp
        LEFT JOIN gen_lista_opciones mp ON mp.id = pp.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pp.id_cuenta_bancaria
        WHERE pp.id_comprobante = p_id AND pp.estado = 1
    ) pg;

    -- Préstamos de cilindro nacidos de esta venta, con TODOS sus balones: no se
    -- filtra por id_estado del detalle ni por fecha_devolucion a propósito. El
    -- comprobante documenta qué cilindros salieron con esa venta; que uno ya
    -- haya vuelto no lo borra de lo que se entregó ese día, solo cambia la
    -- etiqueta de estado que se muestra al costado. Se incluyen ambos roles:
    -- ENTREGADO (lo que se lleva el cliente) y GARANTIA (el cilindro propio que
    -- deja como colateral).
    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.id), '[]'::JSON) INTO v_prestamos
    FROM (
        SELECT
            p.id,
            p.numero_prestamo,
            p.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            p.id_almacen,
            a.nombre AS nombre_almacen,
            p.fecha_salida,
            p.fecha_retorno_pactada,
            p.fecha_retorno_real,
            p.titulo,
            p.observacion,
            p.id_estado,
            ep.nombre AS nombre_estado,
            p.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            (
                SELECT COALESCE(json_agg(row_to_json(bl) ORDER BY bl.rol, bl.id), '[]'::JSON)
                FROM (
                    SELECT
                        pd.id,
                        pd.rol,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie,
                        b.id_tipo_balon,
                        tb.nombre AS nombre_tipo_balon,
                        tb.capacidad,
                        b.id_estado_balon,
                        eb.nombre AS nombre_estado_balon,
                        pd.id_producto,
                        COALESCE(pgas.nombre, prod.nombre) AS nombre_producto,
                        pd.fecha_entregado,
                        pd.fecha_prestamo,
                        pd.fecha_vencimiento,
                        pd.fecha_devolucion,
                        pd.id_estado,
                        epd.nombre AS nombre_estado,
                        pd.motivo_especifico,
                        pd.observacion
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    LEFT JOIN pro_producto prod ON prod.id = pd.id_producto
                    LEFT JOIN pro_producto pgas ON pgas.id = b.id_producto_gas
                    LEFT JOIN gen_lista_opciones epd ON epd.id = pd.id_estado
                    WHERE pd.id_prestamo = p.id AND pd.estado = 1
                ) bl
            ) AS balones
        FROM bal_prestamo p
        LEFT JOIN gen_lista_opciones tp ON tp.id = p.id_tipo_prestamo
        LEFT JOIN gen_almacen a ON a.id = p.id_almacen
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        LEFT JOIN bal_prestamo po ON po.id = p.id_prestamo_origen
        WHERE p.id_comprobante_venta = p_id AND p.estado = 1
    ) pr;

    -- Garantías ligadas a esta venta. Se llega a ellas por tres caminos porque
    -- ven_garantia no guarda id_comprobante: por el préstamo, por el alquiler o
    -- por el movimiento de cobro, que sí apunta al comprobante.
    -- `monto_cobrado_comprobante` es lo que se cobró en ESTA venta; los demás
    -- montos son el estado vigente de la garantía (para pantalla, no para el
    -- ticket impreso, que debe quedar como foto del día de emisión).
    SELECT COALESCE(json_agg(row_to_json(gr) ORDER BY gr.id), '[]'::JSON) INTO v_garantias
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            alq.numero_alquiler,
            g.id_producto,
            prod.nombre AS nombre_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            umg.nombre AS nombre_unidad_medida,
            g.ubicacion,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.id_medio_pago,
            mpg.nombre AS nombre_medio_pago,
            g.observacion,
            COALESCE((
                SELECT SUM(gm.monto)
                FROM ven_garantia_movimiento gm
                INNER JOIN gen_lista_opciones tmg ON tmg.id = gm.id_tipo_movimiento
                WHERE gm.id_garantia = g.id
                  AND gm.id_comprobante = p_id
                  AND gm.estado = 1
                  AND UPPER(tmg.nombre) = 'COBRO'
            ), 0) AS monto_cobrado_comprobante
        FROM ven_garantia g
        LEFT JOIN bal_prestamo pr ON pr.id = g.id_prestamo
        LEFT JOIN bal_alquiler alq ON alq.id = g.id_alquiler
        LEFT JOIN pro_producto prod ON prod.id = g.id_producto
        LEFT JOIN gen_lista_opciones umg ON umg.id = g.id_unidad_medida
        LEFT JOIN gen_lista_opciones eg ON eg.id = g.id_estado
        LEFT JOIN gen_lista_opciones mpg ON mpg.id = g.id_medio_pago
        WHERE g.estado = 1
          AND (
              pr.id_comprobante_venta = p_id
              OR alq.id_comprobante_venta = p_id
              OR EXISTS (
                  SELECT 1
                  FROM ven_garantia_movimiento gm
                  WHERE gm.id_garantia = g.id
                    AND gm.id_comprobante = p_id
                    AND gm.estado = 1
              )
          )
    ) gr;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles,
        'cuotas', v_cuotas,
        'pagos', v_pagos,
        'prestamos', v_prestamos,
        'garantias', v_garantias
    );
END;
$function$;


-- ===== funciones\comprobantes\ven_revertir_nc_sunat_rechazada.sql =====
-- Function: ven_revertir_nc_sunat_rechazada
--
-- Creada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- cuando SUNAT rechaza una nota de crédito, revierte el kardex/efectos de la
-- NC y la soft-borra (estado=0) para liberar el tope de cantidades y permitir
-- emitir otra.
DROP FUNCTION IF EXISTS ven_revertir_nc_sunat_rechazada(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_revertir_nc_sunat_rechazada(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_estado_sunat VARCHAR;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT tc.descripcion, es.nombre
    INTO v_codigo_tipo, v_estado_sunat
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    WHERE c.id = p_id AND c.estado = 1;

    IF v_codigo_tipo IS NULL THEN
        RETURN json_build_object('ok', FALSE, 'error', 'La nota de crédito no existe o ya fue eliminada');
    END IF;

    IF v_codigo_tipo <> '07' THEN
        RETURN json_build_object('ok', FALSE, 'error', 'Solo aplica a notas de crédito');
    END IF;

    IF COALESCE(v_estado_sunat, '') <> 'RECHAZADO' THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', format('La NC no está RECHAZADA (estado SUNAT: %s)', COALESCE(v_estado_sunat, 'NULL'))
        );
    END IF;

    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, FALSE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos de la NC')
        );
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'error', NULL, 'id', p_id);
END;
$function$;


-- ===== funciones\recojos\bal_registrar_resultado_recojo.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_resultado_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date, p_id_motivo_fallo integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_regulador json);

CREATE OR REPLACE FUNCTION bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date DEFAULT NULL::date, p_id_motivo_fallo integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_regulador json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_doc_salida INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_ad INTEGER;
    v_id_b INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_prestamo_det INTEGER;
    v_id_alquiler_det INTEGER;
    v_dev JSON;
    v_cnt_total INTEGER := 0;
    v_cnt_recogido INTEGER := 0;
    v_cnt_no_recogido INTEGER := 0;
    v_cnt_extendido INTEGER := 0;
    v_cnt_efectivo INTEGER := 0;
    v_cnt_cubiertos INTEGER := 0;
    v_estado_header VARCHAR;
    v_id_estado_header INTEGER;
    v_id_motivo INTEGER;
    v_motivo_nombre VARCHAR;
    v_pendientes_json JSONB := '[]'::JSONB;
    v_fecha_repro DATE;
    v_nuevo JSON;
    v_id_estado_prestado INTEGER;
    v_id_balon INTEGER;
    v_repro_detalles JSONB := '[]'::JSONB;
    v_cantidad_restante NUMERIC(10,4);
    v_capacidad_tipo NUMERIC(10,4);
    v_id_producto_gas_recojo INTEGER;
    v_lb_restante NUMERIC(10,4);
    v_peso_bruto_lb NUMERIC(10,4);
    v_presion_psi NUMERIC(10,4);
    v_tiene_regulador BOOLEAN := FALSE;
    v_procesa_regulador BOOLEAN := FALSE;
    v_reg JSONB;
    v_reg_resultado VARCHAR;
    v_reg_condicion VARCHAR;
    v_reg_nueva_fecha DATE;
    v_reg_obs VARCHAR(500);
    v_id_resultado_reg INTEGER;
    v_id_condicion_reg INTEGER;
    v_cil_pendientes INTEGER;
    v_seen_pd INTEGER[] := '{}';
    v_seen_ad INTEGER[] := '{}';
    v_seen_b INTEGER[] := '{}';
    v_ya_devuelto DATE;
    v_pass INTEGER;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, r.id_alquiler, r.id_doc_salida, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_id_alquiler, v_id_doc_salida, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar resultado en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    v_fecha_visita := COALESCE(p_fecha_visita, CURRENT_DATE);

    SELECT COUNT(*)::INTEGER INTO v_cnt_total
    FROM bal_recojo_detalle
    WHERE id_recojo = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL THEN
        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
        INTO v_tiene_regulador
        FROM bal_alquiler a
        WHERE a.id = v_id_alquiler AND a.estado = 1;
    END IF;

    v_reg := CASE
        WHEN p_regulador IS NULL OR p_regulador::TEXT IN ('null', '') THEN NULL
        ELSE p_regulador::JSONB
    END;

    -- Compat: recojo solo regulador enviando un ítem en detalles sin ids de cilindro
    IF v_tiene_regulador
       AND v_reg IS NULL
       AND v_cnt_total = 0
       AND jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 1
       AND COALESCE(
           NULLIF((p_detalles::JSONB -> 0)->>'idPrestamoDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_prestamo_detalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'idAlquilerDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_alquiler_detalle', '')
       ) IS NULL
    THEN
        v_reg := p_detalles::JSONB -> 0;
    END IF;

    -- Regulador solo si visita accesorio-only o el cliente envió p_regulador
    v_procesa_regulador := (v_cnt_total = 0 AND v_tiene_regulador) OR (v_reg IS NOT NULL);

    IF v_cnt_total = 0 THEN
        IF NOT v_tiene_regulador THEN
            RETURN json_build_object(
                'error', 'Este recojo no tiene detalles ni regulador asociado',
                'registro', NULL
            );
        END IF;
    ELSE
        IF p_detalles IS NULL
           OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
            RETURN json_build_object(
                'error', 'Debe indicar el resultado de al menos un detalle',
                'registro', NULL
            );
        END IF;

        IF v_cnt_total <> jsonb_array_length(p_detalles::JSONB) THEN
            RETURN json_build_object(
                'error',
                'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                'registro', NULL
            );
        END IF;
    END IF;

    v_id_motivo := p_id_motivo_fallo;
    IF v_id_motivo IS NOT NULL THEN
        SELECT lo.nombre INTO v_motivo_nombre
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE lo.id = v_id_motivo
          AND l.nombre = 'MotivoFalloRecojo'
          AND lo.estado = 1;

        IF v_motivo_nombre IS NULL THEN
            RETURN json_build_object(
                'error', 'El motivo de fallo no existe o no pertenece a MotivoFalloRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Pass 1: validar cilindros. Antes del pass 2: regulador + FALLIDO + reprogram.
    -- Pass 2: mutar stock / fechas.
    FOR v_pass IN 1..2 LOOP
        v_seen_pd := '{}';
        v_seen_ad := '{}';
        v_seen_b := '{}';
        IF v_pass = 1 THEN
            v_cnt_recogido := 0;
            v_cnt_no_recogido := 0;
            v_cnt_extendido := 0;
            v_pendientes_json := '[]'::JSONB;
        END IF;

        IF v_pass = 2 THEN
            IF v_procesa_regulador THEN
                IF v_reg IS NULL OR COALESCE(NULLIF(TRIM(COALESCE(
                    v_reg->>'resultado', v_reg->>'nombre_resultado', ''
                )), ''), '') = '' THEN
                    RETURN json_build_object(
                        'error', 'Debe indicar el resultado del regulador/accesorio',
                        'registro', NULL
                    );
                END IF;

                v_reg_resultado := UPPER(TRIM(COALESCE(
                    v_reg->>'resultado',
                    v_reg->>'nombre_resultado',
                    ''
                )));
                v_reg_condicion := UPPER(TRIM(COALESCE(
                    v_reg->>'condicion',
                    v_reg->>'nombreCondicion',
                    v_reg->>'nombre_condicion',
                    ''
                )));
                v_reg_nueva_fecha := COALESCE(
                    NULLIF(v_reg->>'nuevaFechaRetorno', '')::DATE,
                    NULLIF(v_reg->>'nueva_fecha_retorno', '')::DATE
                );
                v_reg_obs := NULLIF(TRIM(COALESCE(v_reg->>'observacion', '')), '');

                IF v_reg_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
                    RETURN json_build_object(
                        'error', 'Resultado de regulador inválido: ' || COALESCE(v_reg_resultado, '(vacío)'),
                        'registro', NULL
                    );
                END IF;

                SELECT lo.id INTO v_id_resultado_reg
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'ResultadoRecojoDetalle'
                  AND lo.nombre = v_reg_resultado
                  AND lo.estado = 1
                LIMIT 1;

                IF v_id_resultado_reg IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se encontró el resultado ' || v_reg_resultado || ' en ResultadoRecojoDetalle',
                        'registro', NULL
                    );
                END IF;

                IF v_reg_resultado = 'RECOGIDO' THEN
                    IF v_reg_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
                        RETURN json_build_object(
                            'error', 'Debe indicar si el regulador está BUENO o PARA_REPARAR',
                            'registro', NULL
                        );
                    END IF;

                    SELECT lo.id INTO v_id_condicion_reg
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    WHERE l.nombre = 'CondicionRegulador'
                      AND lo.nombre = v_reg_condicion
                      AND lo.estado = 1
                    LIMIT 1;

                    IF v_id_condicion_reg IS NULL THEN
                        RETURN json_build_object(
                            'error', 'No se encontró la condición ' || v_reg_condicion || ' en CondicionRegulador',
                            'registro', NULL
                        );
                    END IF;

                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_reg_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'solo_regulador', TRUE,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_reg_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            END IF;

            v_cnt_efectivo := v_cnt_total + CASE WHEN v_procesa_regulador THEN 1 ELSE 0 END;

            IF v_cnt_efectivo = 0 THEN
                RETURN json_build_object(
                    'error', 'No hay ítems para registrar en este recojo',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido = v_cnt_efectivo THEN
                v_estado_header := 'FALLIDO';
            ELSIF v_cnt_no_recogido > 0 THEN
                v_estado_header := 'REPROGRAMADO';
            ELSE
                v_estado_header := 'EXITOSO';
            END IF;

            SELECT lo.id INTO v_id_estado_header
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_header AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_header IS NULL THEN
                RETURN json_build_object(
                    'error', 'No se encontró el estado ' || v_estado_header || ' en EstadoRecojo',
                    'registro', NULL
                );
            END IF;

            IF v_estado_header = 'FALLIDO' AND v_id_motivo IS NULL THEN
                RETURN json_build_object(
                    'error', 'Debe indicar el motivo de fallo cuando el recojo es FALLIDO',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido > 0 THEN
                SELECT MIN((elem->>'nueva_fecha_retorno')::DATE)
                INTO v_fecha_repro
                FROM jsonb_array_elements(v_pendientes_json) elem;

                v_fecha_repro := COALESCE(v_fecha_repro, v_fecha_visita + 1);

                SELECT COALESCE(
                    jsonb_agg(
                        CASE
                            WHEN NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_prestamo_detalle', (elem->>'id_prestamo_detalle')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            WHEN NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_alquiler_detalle', (elem->>'id_alquiler_detalle')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            WHEN NULLIF(elem->>'id_balon', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_balon', (elem->>'id_balon')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            ELSE NULL
                        END
                    ) FILTER (WHERE COALESCE(elem->>'solo_regulador', 'false') <> 'true'
                              AND (
                                  NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_balon', '') IS NOT NULL
                              )),
                    '[]'::JSONB
                )
                INTO v_repro_detalles
                FROM jsonb_array_elements(v_pendientes_json) elem;

                IF v_id_cliente IS NULL OR v_fecha_repro IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: faltan cliente o fecha',
                        'registro', NULL
                    );
                END IF;

                IF v_id_doc_salida IS NULL
                   AND COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0
                   AND v_id_alquiler IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: no hay pendientes válidos',
                        'registro', NULL
                    );
                END IF;
            END IF;
        END IF;

        FOR v_item IN
            SELECT * FROM jsonb_array_elements(
                CASE WHEN v_cnt_total = 0 THEN '[]'::JSONB ELSE p_detalles::JSONB END
            )
        LOOP
            v_id_pd := COALESCE(
                NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
            );
            v_id_ad := COALESCE(
                NULLIF(v_item->>'idAlquilerDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_alquiler_detalle', '')::INTEGER
            );
            v_id_b := COALESCE(
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'id_balon', '')::INTEGER
            );
            v_resultado := UPPER(TRIM(COALESCE(
                v_item->>'resultado',
                v_item->>'nombre_resultado',
                ''
            )));
            v_nombre_contenido := NULLIF(TRIM(COALESCE(
                v_item->>'nombreEstadoContenido',
                v_item->>'nombre_estado_contenido',
                ''
            )), '');
            v_nueva_fecha := COALESCE(
                NULLIF(v_item->>'nuevaFechaRetorno', '')::DATE,
                NULLIF(v_item->>'nueva_fecha_retorno', '')::DATE
            );
            v_id_almacen := COALESCE(
                NULLIF(v_item->>'idAlmacenDestino', '')::INTEGER,
                NULLIF(v_item->>'id_almacen_destino', '')::INTEGER
            );
            v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');
            v_cantidad_restante := COALESCE(
                NULLIF(v_item->>'cantidadRestante', '')::NUMERIC,
                NULLIF(v_item->>'cantidad_restante', '')::NUMERIC
            );
            v_lb_restante := COALESCE(
                NULLIF(v_item->>'lbRetorno', '')::NUMERIC,
                NULLIF(v_item->>'lb_retorno', '')::NUMERIC
            );
            v_peso_bruto_lb := COALESCE(
                NULLIF(v_item->>'pesoBrutoLb', '')::NUMERIC,
                NULLIF(v_item->>'peso_bruto_lb', '')::NUMERIC
            );
            v_presion_psi := COALESCE(
                NULLIF(v_item->>'presionActual', '')::NUMERIC,
                NULLIF(v_item->>'presion_actual', '')::NUMERIC,
                NULLIF(v_item->>'presionPsi', '')::NUMERIC,
                NULLIF(v_item->>'presion_psi', '')::NUMERIC
            );

            IF (v_id_pd IS NOT NULL)::INTEGER + (v_id_ad IS NOT NULL)::INTEGER + (v_id_b IS NOT NULL)::INTEGER <> 1 THEN
                RETURN json_build_object(
                    'error', 'Cada detalle debe indicar id_prestamo_detalle, id_alquiler_detalle o id_balon',
                    'registro', NULL
                );
            END IF;

            IF v_id_pd IS NOT NULL THEN
                IF v_id_pd = ANY(v_seen_pd) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de préstamo duplicado: ' || v_id_pd,
                        'registro', NULL
                    );
                END IF;
                v_seen_pd := array_append(v_seen_pd, v_id_pd);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_ad IS NOT NULL THEN
                IF v_id_ad = ANY(v_seen_ad) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de alquiler duplicado: ' || v_id_ad,
                        'registro', NULL
                    );
                END IF;
                v_seen_ad := array_append(v_seen_ad, v_id_ad);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_alquiler_detalle = v_id_ad AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de alquiler ' || v_id_ad || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_b IS NOT NULL THEN
                IF v_id_b = ANY(v_seen_b) THEN
                    RETURN json_build_object(
                        'error', 'Balón duplicado en el recojo: ' || v_id_b,
                        'registro', NULL
                    );
                END IF;
                v_seen_b := array_append(v_seen_b, v_id_b);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_balon = v_id_b AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El balón ' || v_id_b || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
                RETURN json_build_object(
                    'error', 'Resultado inválido: ' || COALESCE(v_resultado, '(vacío)'),
                    'registro', NULL
                );
            END IF;

            SELECT lo.id INTO v_id_resultado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'ResultadoRecojoDetalle' AND lo.nombre = v_resultado AND lo.estado = 1
            LIMIT 1;

            IF v_id_resultado IS NULL THEN
                RETURN json_build_object(
                    'error', 'No se encontró el resultado ' || v_resultado || ' en ResultadoRecojoDetalle',
                    'registro', NULL
                );
            END IF;



            IF v_resultado = 'EXTENDIDO' THEN
                v_nueva_fecha := COALESCE(v_nueva_fecha, v_fecha_visita + 1);
            END IF;

            IF v_resultado = 'RECOGIDO' THEN
                IF v_id_pd IS NOT NULL THEN
                    SELECT pd.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_prestamo_detalle pd
                    JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE pd.id = v_id_pd AND pd.estado = 1;
                ELSIF v_id_ad IS NOT NULL THEN
                    SELECT ad.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_alquiler_detalle ad
                    JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE ad.id = v_id_ad AND ad.estado = 1;
                ELSE
                    v_id_balon := v_id_b;
                    SELECT tb.capacidad
                    INTO v_capacidad_tipo
                    FROM bal_balon b
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE b.id = v_id_b AND b.estado = 1;
                END IF;

                IF v_cantidad_restante IS NULL THEN
                    IF UPPER(COALESCE(v_nombre_contenido, 'VACIO')) = 'VACIO' THEN
                        v_cantidad_restante := 0;
                    ELSIF UPPER(COALESCE(v_nombre_contenido, '')) = 'LLENO' THEN
                        v_cantidad_restante := v_capacidad_tipo;
                    END IF;
                ELSIF v_cantidad_restante < 0 THEN
                    RETURN json_build_object(
                        'error', 'La cantidad restante no puede ser negativa',
                        'registro', NULL
                    );
                ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante > v_capacidad_tipo THEN
                    RETURN json_build_object(
                        'error',
                        'La cantidad restante (' || v_cantidad_restante
                            || ') supera la capacidad del cilindro (' || v_capacidad_tipo || ')',
                        'registro', NULL
                    );
                END IF;

                IF v_nombre_contenido IS NULL AND v_cantidad_restante IS NOT NULL THEN
                    IF v_cantidad_restante <= 0 THEN
                        v_nombre_contenido := 'VACIO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante >= v_capacidad_tipo THEN
                        v_nombre_contenido := 'LLENO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante < v_capacidad_tipo THEN
                        v_nombre_contenido := 'SEMILLLENO';
                    ELSE
                        v_nombre_contenido := 'DESCONOCIDO';
                    END IF;
                END IF;
            ELSE
                v_cantidad_restante := NULL;
                v_id_balon := NULL;
            END IF;

            IF v_pass = 1 THEN
                IF v_resultado = 'RECOGIDO' THEN
                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'id_prestamo_detalle', v_id_pd,
                            'id_alquiler_detalle', v_id_ad,
                            'id_balon', v_id_b,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            ELSE
                UPDATE bal_recojo_detalle
                SET
                    id_resultado = v_id_resultado,
                    cantidad_restante = CASE
                        WHEN v_resultado = 'RECOGIDO' THEN v_cantidad_restante
                        ELSE cantidad_restante
                    END,
                    nueva_fecha_retorno = CASE
                        WHEN v_resultado = 'EXTENDIDO' THEN v_nueva_fecha
                        ELSE nueva_fecha_retorno
                    END,
                    id_almacen_destino = COALESCE(v_id_almacen, id_almacen_destino),
                    observacion = COALESCE(v_obs, observacion),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id_recojo = p_id
                  AND estado = 1
                  AND (
                      (v_id_pd IS NOT NULL AND id_prestamo_detalle = v_id_pd)
                      OR (v_id_ad IS NOT NULL AND id_alquiler_detalle = v_id_ad)
                      OR (v_id_b IS NOT NULL AND id_balon = v_id_b)
                  );

                IF v_resultado = 'RECOGIDO' THEN
                    v_dev := NULL;
                    IF v_id_pd IS NOT NULL THEN
                        SELECT pd.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_prestamo_detalle pd
                        WHERE pd.id = v_id_pd AND pd.estado = 1;
                    ELSIF v_id_ad IS NOT NULL THEN
                        SELECT ad.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_alquiler_detalle ad
                        WHERE ad.id = v_id_ad AND ad.estado = 1;
                    ELSE
                        v_ya_devuelto := NULL;
                    END IF;

                    IF v_ya_devuelto IS NULL THEN
                        IF v_id_pd IS NOT NULL THEN
                            v_dev := bal_devolver_prestamo_detalle(
                                v_id_pd,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria,
                                COALESCE(v_nombre_contenido, 'VACIO'),
                                v_obs
                            );
                        ELSIF v_id_ad IS NOT NULL THEN
                            v_dev := bal_devolver_alquiler_detalle(
                                v_id_ad,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria
                            );
                        ELSE
                            -- Recarga en planta externa: ingreso físico del balón al almacén
                            PERFORM bal_actualizar_balon(
                                p_id                   => v_id_balon,
                                p_id_almacen           => v_id_almacen,
                                p_id_estado_balon      => v_id_estado_en_almacen,
                                p_id_usuario_auditoria => p_id_usuario_auditoria
                            );

                            IF v_id_doc_salida IS NOT NULL THEN
                                -- Mismo candado que bal_finalizar_recarga_planta: si el
                                -- retorno físico (ENTRADA_PLANTA_EXTERNA BALON) ya
                                -- ingresó los cilindros, ENTRADA_LLENADO los duplicaría.
                                IF EXISTS (
                                    SELECT 1
                                    FROM inv_movimiento m
                                    JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
                                    JOIN gen_lista_opciones td ON td.id = m.id_tipo_documento_origen
                                    WHERE m.estado = 1
                                      AND m.naturaleza = 'BALON'
                                      AND m.id_balon = v_id_balon
                                      AND m.id_documento_origen = v_id_doc_salida
                                      AND UPPER(TRIM(tm.nombre)) = 'ENTRADA_PLANTA_EXTERNA'
                                      AND UPPER(TRIM(td.nombre)) = 'ORDEN_SALIDA'
                                ) THEN
                                    RAISE EXCEPTION
                                        'El cilindro #%s ya retornó por ENTRADA_PLANTA_EXTERNA de la orden #%s; no se registra ENTRADA_LLENADO',
                                        v_id_balon, v_id_doc_salida;
                                END IF;

                                SELECT id_producto_gas INTO v_id_producto_gas_recojo
                                FROM bal_balon WHERE id = v_id_balon;

                                v_dev := inv_registrar_movimiento(
                                    p_naturaleza                => 'BALON',
                                    p_codigo_tipo_movimiento    => 'ENTRADA_LLENADO',
                                    p_fecha                     => LOCALTIMESTAMP,
                                    p_id_producto               => v_id_producto_gas_recojo,
                                    p_id_balon                  => v_id_balon,
                                    p_cantidad                  => COALESCE(v_cantidad_restante, NULLIF(v_capacidad_tipo, 0), 1),
                                    p_id_almacen_destino        => v_id_almacen,
                                    p_id_cliente                => v_id_cliente,
                                    p_codigo_tipo_documento_origen => 'RECARGA',
                                    p_id_documento_origen       => v_id_doc_salida,
                                    p_glosa                     => 'Entrada por recojo de recarga en planta (orden #'
                                        || v_id_doc_salida || ')',
                                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                                );
                                IF v_dev->>'error' IS NOT NULL THEN
                                    RAISE EXCEPTION 'No se pudo registrar el movimiento de entrada del balón %: %',
                                        v_id_balon, v_dev->>'error';
                                END IF;
                            END IF;
                        END IF;
                        IF v_dev->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_dev->>'error';
                        END IF;
                    END IF;

                    IF v_id_balon IS NOT NULL AND (
                        v_peso_bruto_lb IS NOT NULL
                        OR v_lb_restante IS NOT NULL
                        OR v_cantidad_restante IS NOT NULL
                    ) THEN
                        NULL;
                    END IF;
                ELSIF v_resultado = 'EXTENDIDO' THEN
                    IF v_id_pd IS NOT NULL THEN
                        SELECT pd.id_prestamo, pd.id_balon
                        INTO v_id_prestamo_det, v_id_balon
                        FROM bal_prestamo_detalle pd
                        WHERE pd.id = v_id_pd AND pd.estado = 1;

                        UPDATE bal_prestamo_detalle
                        SET
                            fecha_vencimiento = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_pd AND estado = 1;

                        UPDATE bal_prestamo
                        SET
                            fecha_retorno_pactada = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_prestamo_det AND estado = 1;
                    ELSIF v_id_ad IS NOT NULL THEN
                        SELECT ad.id_alquiler, ad.id_balon
                        INTO v_id_alquiler_det, v_id_balon
                        FROM bal_alquiler_detalle ad
                        WHERE ad.id = v_id_ad AND ad.estado = 1;

                        UPDATE bal_alquiler
                        SET
                            fecha_fin_pactada = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_alquiler_det AND estado = 1;
                    ELSE
                        -- Recarga planta: detalle solo por id_balon (sin préstamo/alquiler)
                        v_id_balon := v_id_b;
                    END IF;

                    -- Solo préstamo/alquiler revierten POR_RECOGER → estado de custodia.
                    IF v_id_pd IS NOT NULL OR v_id_ad IS NOT NULL THEN
                        SELECT lo.id INTO v_id_estado_prestado
                        FROM gen_lista_opciones lo
                        INNER JOIN gen_lista l ON l.id = lo.id_lista
                        WHERE l.nombre = 'EstadoBalon'
                          AND lo.nombre = CASE WHEN v_id_ad IS NOT NULL THEN 'ALQUILADO' ELSE 'PRESTADO_CLIENTE' END
                          AND lo.estado = 1
                        LIMIT 1;

                        IF v_id_balon IS NOT NULL AND v_id_estado_prestado IS NOT NULL THEN
                            UPDATE bal_balon b
                            SET
                                id_estado_balon = v_id_estado_prestado,
                                id_usuario_modificacion = p_id_usuario_auditoria,
                                fecha_modificacion = NOW()
                            FROM gen_lista_opciones eb
                            WHERE b.id = v_id_balon
                              AND b.estado = 1
                              AND eb.id = b.id_estado_balon
                              AND eb.nombre = 'POR_RECOGER';
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;

        IF v_pass = 1 AND v_cnt_total > 0 THEN
            SELECT COUNT(*)::INTEGER INTO v_cnt_cubiertos
            FROM bal_recojo_detalle rd
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND (
                  (rd.id_prestamo_detalle IS NOT NULL AND rd.id_prestamo_detalle = ANY(v_seen_pd))
                  OR (rd.id_alquiler_detalle IS NOT NULL AND rd.id_alquiler_detalle = ANY(v_seen_ad))
                  OR (rd.id_balon IS NOT NULL AND rd.id_balon = ANY(v_seen_b))
              );

            IF v_cnt_cubiertos <> v_cnt_total THEN
                RETURN json_build_object(
                    'error',
                    'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                    'registro', NULL
                );
            END IF;
        END IF;
    END LOOP;

    -- Mutación de regulador (después de validar todo el payload)
    IF v_procesa_regulador THEN
        IF v_reg_resultado = 'RECOGIDO' THEN
            v_dev := bal_devolver_regulador_alquiler(
                v_id_alquiler,
                v_fecha_visita,
                v_reg_condicion,
                v_reg_obs,
                p_id,
                p_id_usuario_auditoria
            );

            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
        ELSIF v_reg_resultado = 'EXTENDIDO' THEN
            v_reg_nueva_fecha := COALESCE(v_reg_nueva_fecha, v_fecha_visita + 1);

            UPDATE bal_alquiler
            SET
                fecha_fin_pactada = v_reg_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_alquiler AND estado = 1;
        END IF;
    END IF;

    UPDATE bal_recojo
    SET
        fecha_visita = v_fecha_visita,
        id_estado = v_id_estado_header,
        id_motivo_fallo = CASE
            WHEN v_estado_header IN ('FALLIDO', 'REPROGRAMADO') AND v_cnt_no_recogido > 0
                THEN COALESCE(v_id_motivo, id_motivo_fallo)
            WHEN v_estado_header = 'FALLIDO' THEN v_id_motivo
            ELSE id_motivo_fallo
        END,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_resultado_regulador = COALESCE(v_id_resultado_reg, id_resultado_regulador),
        id_condicion_regulador = COALESCE(v_id_condicion_reg, id_condicion_regulador),
        nueva_fecha_retorno_regulador = CASE
            WHEN v_reg_resultado = 'EXTENDIDO' THEN v_reg_nueva_fecha
            ELSE nueva_fecha_retorno_regulador
        END,
        observacion_regulador = COALESCE(v_reg_obs, observacion_regulador),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL AND v_reg_resultado = 'RECOGIDO' THEN
        SELECT COUNT(*)::INTEGER INTO v_cil_pendientes
        FROM bal_alquiler_detalle ad
        WHERE ad.id_alquiler = v_id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL;

        IF v_cil_pendientes = 0 THEN
            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_prestado IS NOT NULL THEN
                v_dev := bal_actualizar_alquiler(
                    v_id_alquiler,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::DATE,
                    NULL::DATE,
                    v_fecha_visita,
                    NULL::NUMERIC,
                    NULL::NUMERIC,
                    v_id_estado_prestado,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    p_id_usuario_auditoria
                );

                IF v_dev->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_dev->>'error';
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_cnt_no_recogido > 0 THEN
        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            CASE
                WHEN COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0 THEN NULL
                ELSE v_id_prestamo
            END,
            v_id_alquiler,
            v_id_doc_salida,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            COALESCE(v_repro_detalles, '[]'::JSONB)::JSON,
            p_id_usuario_auditoria
        );

        IF v_nuevo->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo reprogramar el recojo: %', v_nuevo->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_recojo(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte mutaciones parciales (detalle, stock, regulador, reprogramación)
        -- y expone el error al API en el mismo formato que el resto de bal_*.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


-- ===== funciones\documentos-salida\doc_anular_salida.sql =====
-- Function: doc_anular_salida
--
-- Anula el ciclo de la OS y libera custodia logística (PENDIENTE_ENVIO /
-- EN_TRANSITO → DISPONIBLE). Si hay reparto vigente, hay que cancelarlo antes.
-- También se invoca en cascada desde ven_eliminar_comprobante (path con
-- id_venta): ese camino no pasa por inv_revertir_por_documento, así que la
-- liberación de balones vive aquí.
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
-- una orden de planta con compra activa vinculada no se anula (anular la
-- compra primero). Con ello la reversa por ORDEN_SALIDA cubre ida + retorno
-- completos (envases y gas declarado en la orden).
--
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el id del estado ANULADA se resuelve antes de revertir inventario.
--
-- Actualizada por database_sql/migraciones/20260910_venta_custodia_mostrador_anular.sql:
-- un REPARTO ya REALIZADA bloquea la anulación. La entrega ocurrió: los
-- cilindros están EN_PODER_CLIENTE y liberarlos a DISPONIBLE inventaría
-- envases que no tenemos. La corrección documental es una nota de crédito.
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- bloquea si hay bal_recojo PROGRAMADO/EN_RUTA con id_doc_salida = p_id.
DROP FUNCTION IF EXISTS doc_anular_salida(p_id integer, p_motivo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_anular_salida(p_id integer, p_motivo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_compra RECORD;
    v_id_anulada INTEGER;
    v_rev JSON;
    v_id_disponible INTEGER;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o ya fue eliminado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El documento fue aceptado por SUNAT; requiere comunicación de baja, no anulación directa',
            'registro', NULL
        );
    END IF;

    -- Ticket PSE pendiente: anular rompería el correlativo/ticket en SUNAT
    -- sin poder reconciliar (consultarEstado rechaza ANULADA).
    IF NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'La guía tiene un ticket SUNAT pendiente; consulta el CDR o espera la aceptación antes de anular',
            'registro', NULL
        );
    END IF;

    -- Orden de planta con factura vinculada: la compra tiene su gas del retorno
    -- etiquetado COMPRA, que la reversa por ORDEN_SALIDA no alcanza. Anular la
    -- compra primero (que desvincula y ajusta el gas) deja todo consistente.
    IF v_doc.id_comprobante_compra IS NOT NULL AND EXISTS (
        SELECT 1 FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra AND c.estado = 1
    ) THEN
        SELECT c.serie, c.numero INTO v_compra
        FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra;

        RETURN json_build_object(
            'error', format(
                'La orden tiene la compra %s vinculada; anúlala primero en Compras',
                COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), ''), '#' || v_doc.id_comprobante_compra)
            ),
            'registro', NULL
        );
    END IF;

    -- Entrega ya realizada: los cilindros pasaron a EN_PODER_CLIENTE y el
    -- cliente se quedó con ellos. Anular repondría stock inexistente, así que
    -- se bloquea aquí y también en la cascada desde ven_eliminar_comprobante.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'El reparto de esta orden ya fue entregado al cliente; no se puede anular. '
            || 'Registra la devolución de los cilindros o emite una nota de crédito.',
            'registro', NULL
        );
    END IF;

    -- No anular si hay reparto / actividad operativa todavía vigente.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN (
              'CANCELADA', 'CANCELADO', 'REALIZADA'
          )
    ) THEN
        RETURN json_build_object(
            'error', 'Hay actividad de reparto vigente; cancélala antes de anular la OS',
            'registro', NULL
        );
    END IF;

    -- Recojo vivo de planta: anular la OS dejaría el recojo apuntando a un
    -- documento muerto y, al cerrarlo, ENTRADA_LLENADO sin ida que revertir.
    IF EXISTS (
        SELECT 1
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id_doc_salida = p_id
          AND r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
    ) THEN
        RETURN json_build_object(
            'error',
            'La orden tiene un recojo programado o en ruta; ciérralo o cancélalo antes de anularla',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_disponible
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_disponible IS NULL OR v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados DISPONIBLE, PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    -- El estado ANULADA se resuelve antes de revertir inventario: si faltara en
    -- el catálogo, el error soft se devolvía con los movimientos ya revertidos y
    -- la orden seguía activa.
    SELECT lo.id INTO v_id_anulada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'ANULADA' AND lo.estado = 1;

    IF v_id_anulada IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado ANULADA en catalogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    -- Solo se revierte lo que este documento movió por su cuenta.
    IF v_doc.id_venta IS NULL THEN
        v_rev := inv_revertir_por_documento('ORDEN_SALIDA', p_id, p_id_usuario_auditoria);

        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;

        UPDATE doc_salida_detalle
        SET id_movimiento = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_doc_salida = p_id;
    END IF;

    -- ------------------------------------------------------------
    -- Custodia logística: PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE
    --
    -- Con id_venta el inventario lo movió la venta (no hay movimiento OS),
    -- pero los cilindros sí quedaron comprometidos al crear la OS
    -- (doc_crear_desde_venta). Sin esto quedan atrapados al anular.
    -- Sin id_venta, cubre residuales que no hayan pasado por kardex BALON.
    -- ------------------------------------------------------------
    UPDATE bal_balon b
    SET id_estado_balon = v_id_disponible,
        id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE b.estado = 1
      AND b.id_estado_balon IN (v_id_pend_envio, v_id_transito)
      AND b.id IN (
          SELECT dd.id_balon
          FROM doc_salida_detalle dd
          WHERE dd.id_doc_salida = p_id
            AND dd.id_balon IS NOT NULL
            AND dd.estado = 1
          UNION
          SELECT vd.id_balon
          FROM ven_comprobante_detalle vd
          WHERE v_doc.id_venta IS NOT NULL
            AND vd.id_comprobante = v_doc.id_venta
            AND vd.id_balon IS NOT NULL
            AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
          UNION
          -- Misma cobertura que doc_crear_desde_venta / doc_obtener_salida
          SELECT pd.id_balon
          FROM bal_prestamo pr
          INNER JOIN bal_prestamo_detalle pd
              ON pd.id_prestamo = pr.id AND pd.estado = 1
          WHERE v_doc.id_venta IS NOT NULL
            AND pr.id_comprobante_venta = v_doc.id_venta
            AND pr.estado = 1
            AND pd.rol = 'ENTREGADO'
            AND pd.id_balon IS NOT NULL
      );

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_anulada,
        observaciones = TRIM(BOTH ' ' FROM CONCAT_WS(' | ',
            NULLIF(observaciones, ''),
            'Anulada: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'))),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- ===== funciones\prestamos-detalle\bal_devolver_prestamo_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- al devolver, cancela recojos vivos (PROGRAMADO/EN_RUTA) del préstamo.
DROP FUNCTION IF EXISTS bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer, p_nombre_estado_contenido character varying, p_observacion character varying);

CREATE OR REPLACE FUNCTION bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_nombre_estado_contenido character varying DEFAULT 'VACIO'::character varying, p_observacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_obs_actual VARCHAR(500);
    v_obs_nueva VARCHAR(500);
    v_retorno JSON;
    v_id_producto_gas INTEGER;
    v_id_recojo INTEGER;
    v_cancel JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.observacion,
        p.id_cliente,
        p.id_almacen
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_obs_actual,
        v_id_cliente,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1
    FOR UPDATE OF pd;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de préstamo no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    SELECT lo.id INTO v_id_estado_detalle_devuelto
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
    LIMIT 1;

    v_obs_nueva := NULLIF(TRIM(p_observacion), '');
    IF v_obs_nueva IS NOT NULL THEN
        IF NULLIF(TRIM(v_obs_actual), '') IS NULL THEN
            v_obs_actual := LEFT(v_obs_nueva, 500);
        ELSE
            v_obs_actual := LEFT(TRIM(v_obs_actual) || ' | ' || v_obs_nueva, 500);
        END IF;
    END IF;

    IF v_id_balon IS NOT NULL THEN
        SELECT b.id_producto_gas INTO v_id_producto_gas
        FROM bal_balon b
        WHERE b.id = v_id_balon AND b.estado = 1;

        v_retorno := bal_prestamo_aplicar_retorno_cilindro(
            v_id_balon,
            v_id_prestamo,
            v_id_cliente,
            v_id_almacen_destino,
            COALESCE(NULLIF(TRIM(p_nombre_estado_contenido), ''), 'VACIO'),
            COALESCE(v_obs_nueva, 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria,
            TRUE
        );

        IF v_retorno->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_retorno->>'error', 'registro', NULL);
        END IF;
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_estado = COALESCE(v_id_estado_detalle_devuelto, id_estado),
        id_producto = COALESCE(v_id_producto_gas, id_producto),
        observacion = COALESCE(v_obs_actual, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    PERFORM bal_prestamo_cerrar_si_completo(
        v_id_prestamo,
        COALESCE(p_fecha_devolucion, CURRENT_DATE),
        p_id_usuario_auditoria
    );

    -- Devolución manual (o vía resultado): el recojo programado ya no aplica.
    -- Se cancela después de marcar fecha_devolucion para que POR_RECOGER de
    -- este detalle no se revierta a PRESTADO_CLIENTE.
    FOR v_id_recojo IN
        SELECT r.id
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id_prestamo = v_id_prestamo
          AND r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
        ORDER BY r.id
    LOOP
        v_cancel := bal_actualizar_recojo(
            p_id => v_id_recojo,
            p_estado_nombre => 'CANCELADO',
            p_id_usuario_auditoria => p_id_usuario_auditoria
        );
        IF v_cancel->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_cancel->>'error', 'registro', NULL);
        END IF;
    END LOOP;

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;


-- ===== funciones\alquileres-detalle\bal_devolver_alquiler_detalle.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
--
-- Actualizada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- al devolver, cancela recojos vivos (PROGRAMADO/EN_RUTA) del alquiler.
DROP FUNCTION IF EXISTS bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_finalizado INTEGER;
    v_mov_result JSON;
    v_pendientes INTEGER;
    v_nombre_estado_balon VARCHAR;
    v_id_recojo INTEGER;
    v_cancel JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_alquiler,
        ad.id_balon,
        ad.fecha_devolucion,
        al.id_cliente,
        al.id_almacen
    INTO
        v_id_alquiler,
        v_id_balon,
        v_fecha_devolucion,
        v_id_cliente,
        v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1
    FOR UPDATE OF ad;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de alquiler no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacén de destino de la devolución',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacén de destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    SELECT UPPER(TRIM(eb.nombre))
    INTO v_nombre_estado_balon
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = v_id_balon AND b.estado = 1;

    IF v_nombre_estado_balon IS NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro del detalle no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    -- Solo forzar DISPONIBLE si el balón está en un estado esperado de alquiler.
    IF v_nombre_estado_balon NOT IN ('ALQUILADO', 'POR_RECOGER') THEN
        RETURN json_build_object(
            'error',
            format(
                'No se puede devolver: el cilindro está %s (se esperaba ALQUILADO o POR_RECOGER)',
                LOWER(REPLACE(v_nombre_estado_balon, '_', ' '))
            ),
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_alquiler_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    v_mov_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
        p_fecha                     => LOCALTIMESTAMP,
        p_id_balon                  => v_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_destino        => v_id_almacen_destino,
        p_id_cliente                => v_id_cliente,
        p_codigo_tipo_documento_origen => 'ALQUILER',
        p_id_documento_origen       => v_id_alquiler,
        p_glosa                     => 'Entrada por devolución de alquiler',
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- Custodia: vuelve a almacén. Contenido: se asume vacío (envase usado que regresa).
    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = v_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_id_balon
      AND estado = 1;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_alquiler_detalle
    WHERE id_alquiler = v_id_alquiler
      AND estado = 1
      AND fecha_devolucion IS NULL;

    -- No cerrar si aún falta devolver el regulador/accesorio
    IF v_pendientes = 0
       AND NOT EXISTS (
           SELECT 1
           FROM bal_alquiler a
           WHERE a.id = v_id_alquiler
             AND a.estado = 1
             AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
             AND a.fecha_devolucion_regulador IS NULL
       )
    THEN
        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, COALESCE(p_fecha_devolucion, CURRENT_DATE)),
            id_estado = COALESCE(v_id_estado_finalizado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_alquiler
          AND estado = 1;
    END IF;

    -- Devolución manual (o vía resultado): el recojo programado ya no aplica.
    FOR v_id_recojo IN
        SELECT r.id
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id_alquiler = v_id_alquiler
          AND r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
        ORDER BY r.id
    LOOP
        v_cancel := bal_actualizar_recojo(
            p_id => v_id_recojo,
            p_estado_nombre => 'CANCELADO',
            p_id_usuario_auditoria => p_id_usuario_auditoria
        );
        IF v_cancel->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_cancel->>'error';
        END IF;
    END LOOP;

    RETURN bal_obtener_alquiler_detalle(p_id);
EXCEPTION
    WHEN OTHERS THEN
        -- Revierte fecha_devolucion / movimiento parcial y expone al API.
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


