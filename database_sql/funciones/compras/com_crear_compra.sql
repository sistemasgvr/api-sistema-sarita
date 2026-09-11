-- p_id_doc_salida: antes se llamaba p_id_recarga_planta. Desde la Fase 2 la
-- orden de recarga vive en doc_salida, así que el nombre viejo apuntaba a una
-- tabla que ya no existe. Misma posición en la firma: las llamadas posicionales
-- no cambian.
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql:
--   el retorno de cilindros desde Compras solo lo dispara el checkbox
--   (p_registrar_retorno_balones), ya no la fecha de llegada; no exige
--   lote/vencimiento/P.H. (el protocolo va por la ficha ICP del documento de
--   salida); y si la orden ya tiene fecha_llegada_almacen (retorno registrado
--   desde el documento de salida) solo vincula la compra, sin volver a mover
--   inventario.
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · la orden se bloquea (FOR UPDATE) al validarla: dos compras simultáneas
--     ya no pueden vincular la misma orden (además hay índice único parcial
--     sobre com_comprobante_compra.id_doc_salida);
--   · exige la orden GENERADA / EMITIDA_SUNAT (se quita el check muerto de
--     'CERRADO', que no existe en EstadoCicloSalida);
--   · si el retorno ya estaba registrado, al vincular la factura el gas se
--     re-sincroniza a las cantidades facturadas
--     (bal_sincronizar_gas_retorno_planta) y no se pisa el almacén de llegada;
--   · se elimina p_id_guia_retorno: nunca se persistía (la GRE del proveedor
--     va como serie/número de guía de ingreso, referencial).
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   · "el retorno ya está registrado" pasa a mirar la ENTRADA_PLANTA_EXTERNA
--     vigente de los envases, no fecha_llegada_almacen. Una orden con la fecha
--     puesta pero sin entrada física (finalizar sin "guardar en almacén")
--     hacía que la compra se saltara el retorno: los cilindros se quedaban
--     EN_RECARGA_EXTERNA y el gas nunca ingresaba;
--   · el almacén de llegada ya no pisa doc_salida.id_almacen (origen de la
--     salida): va a id_almacen_retorno.
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_recarga_planta integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);

CREATE OR REPLACE FUNCTION com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT false, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_registrar_retorno_balones boolean DEFAULT false, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_compra           INTEGER;
    v_link_planta         JSON;
    v_id_detalle          INTEGER;
    v_item                INTEGER := 0;
    v_linea               JSONB;
    v_id_producto         INTEGER;
    v_id_almacen_compra   INTEGER;
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_importe             NUMERIC(12,4);
    v_total_bruto         NUMERIC(12,4) := 0;
    v_tasa_igv            NUMERIC(6,4) := 0.18;
    v_base_imponible      NUMERIC(12,4);
    v_igv_calculado       NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
    v_ref_estado          INTEGER;
    v_ref_serie           VARCHAR;
    v_ref_numero          VARCHAR;
    v_glosa_final         VARCHAR;
    v_orden               RECORD;
    v_registrar_retorno   BOOLEAN;
    v_retorno_ya_registrado BOOLEAN := FALSE;
    v_id_tipo_entrada_planta INTEGER;
    v_fecha_llegada       DATE;
    v_lote                VARCHAR;
    v_fecha_venc_lote     DATE;
    v_fecha_ph            DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de la compra es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- El detalle de productos es opcional: se puede registrar la cabecera
    -- (por ejemplo, ligada a una orden de recarga en planta externa) y
    -- agregar las líneas después con com_crear_compra_detalle.
    IF p_detalles IS NOT NULL AND jsonb_typeof(p_detalles) IS DISTINCT FROM 'array' THEN
        RETURN json_build_object('error', 'El detalle de productos debe ser un arreglo JSON', 'registro', NULL);
    END IF;

    v_glosa_final := p_glosa;
    IF p_id_comprobante_referencia IS NOT NULL THEN
        SELECT estado, serie, numero INTO v_ref_estado, v_ref_serie, v_ref_numero
        FROM com_comprobante_compra
        WHERE id = p_id_comprobante_referencia;

        IF v_ref_estado IS NULL THEN
            RETURN json_build_object('error', 'La compra de referencia indicada no existe', 'registro', NULL);
        END IF;

        IF v_ref_estado <> 0 THEN
            RETURN json_build_object(
                'error', 'La compra de referencia debe estar anulada antes de registrar la corrección (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;

        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;

    -- La orden debe existir, estar activa, GENERADA (o con GRE emitida) y sin
    -- otra compra activa vinculada: si no, se estaría facturando la misma orden
    -- dos veces. FOR UPDATE: dos compras que lleguen a la vez por la misma
    -- orden se serializan aquí y la segunda ve el vínculo de la primera.
    IF p_id_doc_salida IS NOT NULL THEN
        SELECT
            rp.id,
            rp.id_proveedor,
            rp.id_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
            rp.fecha_prueba_hidrostatica,
            rp.fecha_llegada_almacen,
            rp.id_lote_protocolo,
            c.id AS id_compra_vinculada,
            c.serie AS serie_compra_vinculada,
            c.numero AS numero_compra_vinculada,
            est.nombre AS estado_ciclo,
            tor.nombre AS tipo_orden
        INTO v_orden
        FROM doc_salida rp
        JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        JOIN gen_lista_opciones tor ON tor.id = rp.id_tipo_orden
        LEFT JOIN com_comprobante_compra c
            ON c.id = rp.id_comprobante_compra AND c.estado = 1
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1
        FOR UPDATE OF rp;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
            RETURN json_build_object('error', 'El documento indicado no es una orden de recarga en planta externa', 'registro', NULL);
        END IF;

        IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden de recarga indicada está anulada'
                    ELSE 'La orden de recarga aún está en borrador: genérala antes de registrar su factura'
                END,
                'registro', NULL
            );
        END IF;

        IF v_orden.id_compra_vinculada IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'La orden de recarga ya tiene la compra %s vinculada; anúlala antes de registrar otra',
                    COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_orden.serie_compra_vinculada, v_orden.numero_compra_vinculada)), ''), '#' || v_orden.id_compra_vinculada)
                ),
                'registro', NULL
            );
        END IF;

        IF v_orden.id_proveedor IS NOT NULL
           AND p_id_proveedor IS NOT NULL
           AND v_orden.id_proveedor <> p_id_proveedor
        THEN
            RETURN json_build_object('error', 'El proveedor de la compra no coincide con el de la orden de recarga', 'registro', NULL);
        END IF;
    END IF;

    -- IDs de listas resueltos una sola vez (no dentro del loop). Solo hace
    -- falta que estén configuradas si de verdad hay líneas que procesar.
    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_ref IS NULL THEN
            RAISE EXCEPTION 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef) en gen_lista_opciones';
        END IF;
    END IF;

    -- Cabecera (totales en 0; se recalculan al final con lo realmente insertado)
    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_compra;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles, '[]'::JSONB))
    LOOP
        v_item := v_item + 1;

        v_id_producto := (v_linea->>'id_producto')::INTEGER;
        v_cantidad := (v_linea->>'cantidad')::NUMERIC;
        v_precio_unitario := COALESCE((v_linea->>'precio_unitario')::NUMERIC, 0);
        v_id_almacen_linea := COALESCE((v_linea->>'id_almacen')::INTEGER, p_id_almacen);

        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;

        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;

        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;

        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;

        -- Payload puede forzar afecta_stock (p.ej. costo de recarga planta = false).
        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

        -- Compra vinculada a orden de planta: el gas lo ingresa solo el retorno
        -- (bal_finalizar_recarga_planta / bal_sincronizar_gas_retorno_planta).
        -- La línea es costo.
        IF p_id_doc_salida IS NOT NULL AND v_es_gas THEN
            v_afecta_stock := FALSE;
        END IF;

        v_importe := v_cantidad * v_precio_unitario;
        v_total_bruto := v_total_bruto + v_importe;

        v_descripcion_linea := v_linea->>'descripcion';
        IF v_descripcion_linea IS NULL THEN
            SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = v_id_producto;
        END IF;

        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
            id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
            afecta_stock, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_compra, v_item,
            (v_linea->>'id_clasificacion_gasto')::INTEGER,
            v_id_producto,
            v_descripcion_linea,
            (v_linea->>'id_unidad_medida')::INTEGER,
            v_id_almacen_linea,
            v_cantidad, v_precio_unitario, v_importe,
            v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_detalle;

        IF v_afecta_stock THEN
            v_result_movimiento := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => p_fecha,
                p_id_producto               => v_id_producto,
                p_id_balon                  => NULL,
                p_cantidad                  => v_cantidad,
                p_id_almacen_origen         => v_id_almacen_linea,
                p_id_almacen_destino        => NULL,
                p_id_cliente                => NULL,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen       => v_id_compra,
                p_id_documento_detalle      => v_id_detalle,
                p_glosa                     => 'Ingreso por compra ' || p_serie || '-' || p_numero,
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF (v_result_movimiento->>'error') IS NOT NULL THEN
                RAISE EXCEPTION '%', v_result_movimiento->>'error';
            END IF;
        END IF;

    END LOOP;

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_id_compra
              AND afecta_stock = TRUE
              AND estado = 1
        )
    WHERE id = v_id_compra;

    -- Vínculo opcional con orden de recarga planta externa (factura de costo).
    -- El gas NO ingresa por líneas de compra: lo ingresa el retorno con las
    -- cantidades de esta factura.
    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        -- Retorno físico: SOLO el checkbox lo dispara. Antes bastaba con que
        -- viniera p_fecha_llegada_almacen, pero el formulario la precarga desde
        -- la orden cuando el retorno ya se registró en el documento de salida,
        -- y eso volvía a disparar el retorno (doble ingreso).
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        -- Lote/venc/P.H. ya no son obligatorios para el retorno: el protocolo se
        -- registra por la ficha ICP desde el documento de salida. Si vienen, se
        -- copian a la orden (COALESCE de abajo).
        v_lote := COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(v_orden.lote), ''));
        v_fecha_venc_lote := COALESCE(p_fecha_vencimiento_lote, v_orden.fecha_vencimiento_lote);
        v_fecha_ph := COALESCE(p_fecha_prueba_hidrostatica, v_orden.fecha_prueba_hidrostatica);

        -- El retorno está hecho cuando los envases tienen su ENTRADA_PLANTA_
        -- EXTERNA vigente, no cuando la orden tiene fecha de llegada. Mismo
        -- criterio que bal_finalizar_recarga_planta y bal_sincronizar_gas_
        -- retorno_planta: una fecha sin entrada física dejaba los cilindros en
        -- planta y el gas sin ingresar, y la compra ni lo intentaba.
        SELECT lo.id INTO v_id_tipo_entrada_planta
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_entrada_planta IS NULL THEN
            RAISE EXCEPTION 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado';
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN doc_salida_detalle dd ON dd.id = m.id_documento_detalle
            WHERE m.estado = 1
              AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
              AND m.naturaleza = 'BALON'
              AND dd.id_doc_salida = p_id_doc_salida
              AND dd.id_balon IS NOT NULL
              AND m.id_balon = dd.id_balon
        ) INTO v_retorno_ya_registrado;

        -- Con el retorno ya registrado (envases + gas) desde el documento de
        -- salida, la compra se vincula y el gas se ajusta a lo facturado, sin
        -- volver a mover los cilindros.
        IF v_registrar_retorno AND NOT v_retorno_ya_registrado THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        -- Serie/número de factura no se replican: quedan en la compra y las
        -- lecturas de la orden los resuelven por JOIN vía este FK.
        -- id_almacen es el origen de la salida y no se toca; el almacén de
        -- llegada solo se escribe cuando el retorno se registra ahora (con
        -- retorno previo manda el almacén donde entraron los cilindros).
        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen_retorno      = CASE
                WHEN v_registrar_retorno THEN COALESCE(p_id_almacen, id_almacen_retorno)
                ELSE id_almacen_retorno
            END,
            serie_guia_ingreso      = COALESCE(NULLIF(TRIM(p_serie_guia_ingreso), ''), serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(NULLIF(TRIM(p_numero_guia_ingreso), ''), numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        IF v_registrar_retorno THEN
            -- El retorno físico de los cilindros (custodia de los envases +
            -- entrada de gas consolidada con las cantidades de esta compra) lo
            -- hace bal_finalizar_recarga_planta. Su parámetro sigue llamándose
            -- p_id_recarga_planta; el rename a p_id_doc_salida fue solo aquí.
            v_link_planta := bal_finalizar_recarga_planta(
                p_id_recarga_planta        => p_id_doc_salida,
                p_id_comprobante_compra    => v_id_compra,
                p_fecha_llegada_almacen    => v_fecha_llegada,
                p_id_almacen               => COALESCE(p_id_almacen, v_id_almacen_compra),
                p_id_proveedor             => p_id_proveedor,
                p_guardar_balones_almacen  => TRUE,
                p_lote                     => v_lote,
                p_fecha_vencimiento_lote   => v_fecha_venc_lote,
                p_fecha_prueba_hidrostatica => v_fecha_ph,
                p_id_usuario_auditoria     => p_id_usuario_auditoria,
                p_id_lote_protocolo        => v_orden.id_lote_protocolo
            );

            IF v_link_planta->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_link_planta->>'error';
            END IF;
        ELSIF v_retorno_ya_registrado THEN
            -- La factura llegó después del retorno: hasta ahora el stock tenía
            -- el gas declarado en la orden; pasa a tener lo facturado. Si el
            -- retorno se registró "sin guardar en almacén" no hay gas que
            -- ajustar y la función no hace nada.
            PERFORM bal_sincronizar_gas_retorno_planta(p_id_doc_salida, p_id_usuario_auditoria);
        END IF;
    END IF;

    -- Crédito / cuotas: genera CxP vinculada a la compra según condición de pago.
    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;
